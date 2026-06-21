import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

// ─── Modelo de agrupación ────────────────────────────────────────────────────

/// Conjunto de preguntas que comparten el mismo archivo de audio.
/// El examen CELPIP reproduce un audio y luego muestra N preguntas sobre él.
@immutable
final class ListeningPart {
  const ListeningPart({
    required this.partNumber,
    required this.partTitle,
    required this.questions,
    this.audioAsset,
    this.audioTranscript,
  });

  final int partNumber;
  final String partTitle;
  final List<Question> questions;

  /// Ruta del asset de audio (puede ser null en entornos de desarrollo).
  final String? audioAsset;

  /// Transcripción del audio — usada como fallback cuando el mp3 no existe.
  final String? audioTranscript;
}

// ─── Estado ──────────────────────────────────────────────────────────────────

/// Estado inmutable del módulo Listening.
@immutable
final class ListeningState {
  const ListeningState({
    this.parts = const [],
    this.currentPartIndex = 0,
    this.audioFinished = false,
    this.isPlaying = false,

    /// true cuando el archivo mp3 no existe y se muestra el transcript como mock.
    this.isMockMode = false,
    this.answers = const {},
    this.isSubmitting = false,
    this.errorMessage,
  });

  final List<ListeningPart> parts;
  final int currentPartIndex;

  /// El audio del part actual terminó de reproducirse (o el mock finalizó).
  final bool audioFinished;

  /// just_audio está activamente reproduciendo.
  final bool isPlaying;

  /// El archivo de audio no existe → se muestra el transcript.
  final bool isMockMode;

  /// questionId → índice de opción seleccionada por el candidato.
  final Map<String, int> answers;

  final bool isSubmitting;
  final String? errorMessage;

  ListeningPart? get currentPart =>
      parts.isEmpty ? null : parts[currentPartIndex];

  bool get isLastPart => currentPartIndex >= parts.length - 1;

  /// El candidato puede avanzar o enviar la sección.
  bool get canAdvance => audioFinished && !isSubmitting;

  ListeningState copyWith({
    List<ListeningPart>? parts,
    int? currentPartIndex,
    bool? audioFinished,
    bool? isPlaying,
    bool? isMockMode,
    Map<String, int>? answers,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ListeningState(
      parts: parts ?? this.parts,
      currentPartIndex: currentPartIndex ?? this.currentPartIndex,
      audioFinished: audioFinished ?? this.audioFinished,
      isPlaying: isPlaying ?? this.isPlaying,
      isMockMode: isMockMode ?? this.isMockMode,
      answers: answers ?? this.answers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

/// Controlador del módulo Listening.
///
/// Principios de reproducción única:
///  - El audio arranca automáticamente al cargar cada part.
///  - No se expone API de pausa, retroceso ni adelanto.
///  - [canAdvance] solo es true tras [ProcessingState.completed].
///  - En modo mock (mp3 ausente), el estado audioFinished se activa al instante
///    para que el flujo de prueba funcione end-to-end.
class ListeningNotifier extends Notifier<ListeningState> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  ListeningState build() {
    // Libera recursos al salir del módulo.
    ref.onDispose(_releasePlayer);
    return const ListeningState();
  }

  // ─── API pública ────────────────────────────────────────────────────────

  /// Agrupa las preguntas por audio y arranca la reproducción del primer part.
  Future<void> initialize(List<Question> questions) async {
    final parts = _groupIntoParts(questions);
    state = ListeningState(parts: parts);
    await _playCurrentPart();
  }

  /// Registra la opción seleccionada y la propaga al ExamSessionNotifier.
  void selectAnswer(String questionId, int selectedIndex) {
    final updated =
        Map<String, int>.from(state.answers)..[questionId] = selectedIndex;
    state = state.copyWith(answers: updated);

    ref.read(examSessionProvider.notifier).recordAnswer(
          Answer(
            questionId: questionId,
            content: MultipleChoiceContent(selectedIndex: selectedIndex),
            answeredAt: DateTime.now(),
          ),
        );
  }

  /// Avanza al siguiente part y arranca su audio.
  Future<void> nextPart() async {
    if (!state.canAdvance || state.isLastPart) return;
    await _stopAndClear();

    state = state.copyWith(
      currentPartIndex: state.currentPartIndex + 1,
      audioFinished: false,
      isPlaying: false,
      isMockMode: false,
      clearError: true,
    );
    await _playCurrentPart();
  }

  /// Detiene el audio, bloquea la UI y delega al ExamSessionNotifier.
  Future<void> submitSection() async {
    if (!state.canAdvance) return;
    state = state.copyWith(isSubmitting: true);
    _releasePlayer();
    await ref.read(examSessionProvider.notifier).submitSection();
  }

  // ─── Audio ──────────────────────────────────────────────────────────────

  Future<void> _playCurrentPart() async {
    final part = state.currentPart;
    if (part == null) return;

    if (part.audioAsset == null) {
      // Sin audioAsset en el JSON → modo mock inmediato.
      state = state.copyWith(isMockMode: true, audioFinished: true);
      return;
    }

    _player ??= AudioPlayer();

    try {
      await _player!.setAsset(part.audioAsset!);
      state = state.copyWith(
        isPlaying: true,
        audioFinished: false,
        isMockMode: false,
      );

      _playerSub?.cancel();
      _playerSub = _player!.playerStateStream.listen((ps) {
        if (ps.processingState == ProcessingState.completed) {
          state = state.copyWith(isPlaying: false, audioFinished: true);
        }
      });

      await _player!.play();
    } catch (_) {
      // El mp3 aún no existe en assets/ → modo transcript (flujo de desarrollo).
      state = state.copyWith(
        isMockMode: true,
        isPlaying: false,
        audioFinished: true,
      );
    }
  }

  Future<void> _stopAndClear() async {
    _playerSub?.cancel();
    _playerSub = null;
    await _player?.stop();
  }

  void _releasePlayer() {
    _playerSub?.cancel();
    _playerSub = null;
    _player?.dispose();
    _player = null;
  }

  // ─── Agrupación por audio ────────────────────────────────────────────────

  /// Agrupa preguntas por audioAsset, preservando el orden original del JSON.
  static List<ListeningPart> _groupIntoParts(List<Question> questions) {
    final orderedKeys = <String>[];
    final grouped = <String, List<Question>>{};

    for (final q in questions) {
      final key = q.audioAsset ?? 'part-${q.part}';
      if (!grouped.containsKey(key)) {
        orderedKeys.add(key);
        grouped[key] = [];
      }
      grouped[key]!.add(q);
    }

    return orderedKeys.map((key) {
      final qs = grouped[key]!;
      final first = qs.first;
      return ListeningPart(
        partNumber: first.part,
        partTitle: first.partTitle,
        questions: qs,
        audioAsset: first.audioAsset,
        audioTranscript: first.audioTranscript,
      );
    }).toList();
  }
}

final listeningProvider =
    NotifierProvider<ListeningNotifier, ListeningState>(
  ListeningNotifier.new,
);
