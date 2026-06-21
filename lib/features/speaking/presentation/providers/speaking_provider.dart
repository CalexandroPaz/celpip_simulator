import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Fase de cada tarea de Speaking.
/// idle → preparing → recording → submitted (irreversible una vez submitted).
enum SpeakingPhase { idle, preparing, recording, submitted }

/// Estado del permiso de micrófono, mapeado desde permission_handler.
enum MicPermission { unchecked, granted, denied, permanentlyDenied }

// ─── Modelo de tarea ─────────────────────────────────────────────────────────

/// Estado inmutable de una tarea individual de Speaking.
@immutable
final class SpeakingTask {
  const SpeakingTask({
    required this.question,
    this.phase = SpeakingPhase.idle,
    this.prepSecondsRemaining,
    this.responseSecondsRemaining,
    this.recordingPath,
  });

  final Question question;
  final SpeakingPhase phase;

  /// Segundos restantes de preparación (visibles durante SpeakingPhase.preparing).
  final int? prepSecondsRemaining;

  /// Segundos restantes de respuesta (visibles durante SpeakingPhase.recording).
  final int? responseSecondsRemaining;

  /// Ruta del archivo de grabación; null si el audio falló o aún no terminó.
  final String? recordingPath;

  bool get isSubmitted => phase == SpeakingPhase.submitted;

  /// true mientras hay una cuenta regresiva activa.
  bool get isActive =>
      phase == SpeakingPhase.preparing || phase == SpeakingPhase.recording;

  SpeakingTask copyWith({
    SpeakingPhase? phase,
    int? prepSecondsRemaining,
    int? responseSecondsRemaining,
    String? recordingPath,
  }) {
    return SpeakingTask(
      question: question,
      phase: phase ?? this.phase,
      prepSecondsRemaining:
          prepSecondsRemaining ?? this.prepSecondsRemaining,
      responseSecondsRemaining:
          responseSecondsRemaining ?? this.responseSecondsRemaining,
      recordingPath: recordingPath ?? this.recordingPath,
    );
  }
}

// ─── Estado ──────────────────────────────────────────────────────────────────

@immutable
final class SpeakingState {
  const SpeakingState({
    this.tasks = const [],
    this.currentTaskIndex = 0,
    this.micPermission = MicPermission.unchecked,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final List<SpeakingTask> tasks;
  final int currentTaskIndex;
  final MicPermission micPermission;
  final bool isSubmitting;
  final String? errorMessage;

  SpeakingTask? get currentTask =>
      tasks.isEmpty ? null : tasks[currentTaskIndex];

  bool get isLastTask => currentTaskIndex >= tasks.length - 1;
  bool get isFirstTask => currentTaskIndex == 0;

  /// Puede avanzar solo si la tarea actual está enviada y no es la última.
  bool get canGoNext =>
      currentTask?.isSubmitted == true && !isLastTask;

  /// Puede enviar la sección solo en la última tarea y después de enviarla.
  bool get canSubmit =>
      currentTask?.isSubmitted == true && isLastTask;

  SpeakingState copyWith({
    List<SpeakingTask>? tasks,
    int? currentTaskIndex,
    MicPermission? micPermission,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SpeakingState(
      tasks: tasks ?? this.tasks,
      currentTaskIndex: currentTaskIndex ?? this.currentTaskIndex,
      micPermission: micPermission ?? this.micPermission,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Reemplaza la tarea en [index] sin tocar el resto del estado.
  SpeakingState updateTask(int index, SpeakingTask updated) {
    if (index < 0 || index >= tasks.length) return this;
    final newTasks = List<SpeakingTask>.from(tasks)..[index] = updated;
    return copyWith(tasks: newTasks);
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

/// Controlador del módulo Speaking.
///
/// Máquina de estados por tarea:
///   idle → [startTask()] → preparing (prepSeconds) → recording (responseSeconds) → submitted
///
/// Restricciones de integridad del examen:
///   - Una vez submitted, la tarea no puede reiniciarse.
///   - nextTask() está bloqueado hasta que la tarea actual esté submitted.
///   - En previousTask() (solo revisión) se bloquea durante prep/recording.
class SpeakingNotifier extends Notifier<SpeakingState> {
  AudioRecorder? _recorder;
  Timer? _timer;

  @override
  SpeakingState build() {
    ref.onDispose(_cleanup);
    return const SpeakingState();
  }

  // ─── Init ──────────────────────────────────────────────────────────────

  /// Carga las tareas y comprueba el permiso de micrófono (sin solicitarlo aún).
  Future<void> initialize(List<Question> questions) async {
    final tasks = questions.map((q) => SpeakingTask(question: q)).toList();
    final status = await Permission.microphone.status;
    state = SpeakingState(
      tasks: tasks,
      micPermission: _toMicPermission(status),
    );
  }

  // ─── Permisos ──────────────────────────────────────────────────────────

  /// Solicita el permiso de micrófono al usuario.
  Future<void> requestPermission() async {
    final result = await Permission.microphone.request();
    state = state.copyWith(micPermission: _toMicPermission(result));
  }

  /// Abre los ajustes del dispositivo (cuando el permiso está denegado permanentemente).
  Future<void> openDeviceSettings() async {
    await openAppSettings();
  }

  // ─── Flujo de tarea ────────────────────────────────────────────────────

  /// Arranca la cuenta regresiva de preparación de la tarea actual.
  /// Si el permiso no está concedido, lo solicita primero.
  Future<void> startTask() async {
    if (state.micPermission != MicPermission.granted) {
      await requestPermission();
      if (state.micPermission != MicPermission.granted) return;
    }

    final taskIdx = state.currentTaskIndex;
    final task = state.currentTask;
    if (task == null || task.phase != SpeakingPhase.idle) return;

    _timer?.cancel();

    var prepRemaining = task.question.prepSeconds ?? 30;

    state = state.updateTask(
      taskIdx,
      task.copyWith(
        phase: SpeakingPhase.preparing,
        prepSecondsRemaining: prepRemaining,
      ),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      prepRemaining--;
      if (prepRemaining <= 0) {
        _timer?.cancel();
        // unawaited: el timer es sync, la grabación es async fire-and-forget.
        unawaited(_startRecording(taskIdx));
      } else {
        state = state.updateTask(
          taskIdx,
          state.tasks[taskIdx].copyWith(prepSecondsRemaining: prepRemaining),
        );
      }
    });
  }

  // ─── Grabación ─────────────────────────────────────────────────────────

  Future<void> _startRecording(int taskIdx) async {
    _recorder ??= AudioRecorder();

    // Detiene cualquier grabación previa (protección ante estados inconsistentes).
    if (await _recorder!.isRecording()) {
      await _recorder!.stop();
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/speaking_${taskIdx}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder!.start(const RecordConfig(), path: path);

      var responseRemaining =
          state.tasks[taskIdx].question.responseSeconds ?? 60;

      state = state.updateTask(
        taskIdx,
        state.tasks[taskIdx].copyWith(
          phase: SpeakingPhase.recording,
          responseSecondsRemaining: responseRemaining,
        ),
      );

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        responseRemaining--;
        if (responseRemaining <= 0) {
          _timer?.cancel();
          unawaited(_stopRecording(taskIdx));
        } else {
          state = state.updateTask(
            taskIdx,
            state.tasks[taskIdx]
                .copyWith(responseSecondsRemaining: responseRemaining),
          );
        }
      });
    } catch (e) {
      // El audio falló (ej. emulador sin micrófono) — marca como submitted
      // sin bloquear el resto del examen.
      state = state
          .updateTask(
            taskIdx,
            state.tasks[taskIdx].copyWith(phase: SpeakingPhase.submitted),
          )
          .copyWith(errorMessage: 'Recording unavailable: $e');
    }
  }

  Future<void> _stopRecording(int taskIdx) async {
    try {
      final path = await _recorder?.stop();

      state = state.updateTask(
        taskIdx,
        state.tasks[taskIdx].copyWith(
          phase: SpeakingPhase.submitted,
          recordingPath: path,
        ),
      );

      if (path != null) {
        ref.read(examSessionProvider.notifier).recordAnswer(
              Answer(
                questionId: state.tasks[taskIdx].question.id,
                content: AudioContent(recordingPath: path),
                answeredAt: DateTime.now(),
              ),
            );
      }
    } catch (e) {
      state = state
          .updateTask(
            taskIdx,
            state.tasks[taskIdx].copyWith(phase: SpeakingPhase.submitted),
          )
          .copyWith(errorMessage: 'Could not save recording: $e');
    }
  }

  // ─── Navegación ────────────────────────────────────────────────────────

  /// Avanza a la siguiente tarea; bloqueado hasta que la actual esté submitted.
  void nextTask() {
    if (!state.canGoNext) return;
    _timer?.cancel();
    state = state.copyWith(
      currentTaskIndex: state.currentTaskIndex + 1,
      clearError: true,
    );
  }

  /// Retrocede para revisar una tarea anterior (solo revisión — no re-graba).
  void previousTask() {
    if (state.isFirstTask) return;
    // No permitir retroceder si hay una cuenta regresiva activa.
    if (state.currentTask?.isActive == true) return;
    state = state.copyWith(currentTaskIndex: state.currentTaskIndex - 1);
  }

  /// Envía la sección completa al ExamSessionNotifier.
  Future<void> submitSection() async {
    state = state.copyWith(isSubmitting: true);
    _cleanup();
    await ref.read(examSessionProvider.notifier).submitSection();
  }

  // ─── Internos ──────────────────────────────────────────────────────────

  static MicPermission _toMicPermission(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return MicPermission.granted;
    if (s.isPermanentlyDenied) return MicPermission.permanentlyDenied;
    return MicPermission.denied;
  }

  void _cleanup() {
    _timer?.cancel();
    _timer = null;
    if (_recorder != null) {
      unawaited(_recorder!.dispose());
      _recorder = null;
    }
  }
}

final speakingProvider =
    NotifierProvider<SpeakingNotifier, SpeakingState>(SpeakingNotifier.new);
