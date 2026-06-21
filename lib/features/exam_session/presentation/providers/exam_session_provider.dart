import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celpip_simulator/core/config/api_config.dart';
import 'package:celpip_simulator/core/constants/exam_constants.dart';
import 'package:celpip_simulator/core/services/exam_timer_service.dart';
import 'package:celpip_simulator/features/exam_session/data/datasources/exam_local_datasource.dart';
import 'package:celpip_simulator/features/exam_session/data/datasources/exam_remote_datasource.dart';
import 'package:celpip_simulator/features/exam_session/data/datasources/exam_remote_datasource_impl.dart';
import 'package:celpip_simulator/features/exam_session/data/repositories/exam_repository_impl.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';
import 'package:celpip_simulator/features/exam_session/domain/repositories/exam_repository.dart';
import 'package:celpip_simulator/features/exam_session/domain/usecases/advance_section.dart';
import 'package:celpip_simulator/features/exam_session/domain/usecases/start_exam.dart';
import 'package:celpip_simulator/features/exam_session/domain/usecases/submit_answer.dart';

// ─── Providers de infraestructura ───────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main() with SharedPreferences.getInstance()');
});

final examLocalDataSourceProvider = Provider<ExamLocalDataSource>(
  (ref) => ExamLocalDataSourceImpl(),
);

/// Datasource remoto: mock durante desarrollo, cliente HTTP real en producción.
///
/// Para activar el cliente real al correr la app:
///   flutter run \
///     --dart-define=USE_MOCK_API=false \
///     --dart-define=API_BASE_URL=http://192.168.1.100:8000
final examRemoteDataSourceProvider = Provider<ExamRemoteDataSource>(
  (ref) => ApiConfig.useMockApi
      ? ExamRemoteDataSourceMock()
      : ExamRemoteDataSourceImpl(),
);

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepositoryImpl(
    local: ref.watch(examLocalDataSourceProvider),
    remote: ref.watch(examRemoteDataSourceProvider),
  );
});

final examTimerServiceProvider = Provider<ExamTimerService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = ExamTimerService(prefs: prefs);
  // Cancela el ticker y el observer cuando el provider se elimina (e.g. en tests).
  ref.onDispose(service.cancelSync);
  return service;
});

// ─── Provider de preguntas por sección (cargadas on-demand) ─────────────────

final sectionQuestionsProvider =
    FutureProvider.family<List<Question>, Section>((ref, section) {
  return ref.watch(examRepositoryProvider).getQuestionsForSection(section);
});

// ─── Provider del tiempo restante (stream de 1 s) ───────────────────────────

/// Estado del temporizador actualizado cada segundo desde ExamTimerService.
class TimerState {
  const TimerState({
    this.sectionRemaining = Duration.zero,
    this.globalRemaining = Duration.zero,
  });
  final Duration sectionRemaining;
  final Duration globalRemaining;
}

final timerStateProvider = StateProvider<TimerState>((ref) => const TimerState());

// ─── Notifier principal ─────────────────────────────────────────────────────

/// Máquina de estados del examen. Única fuente de verdad para la fase,
/// sección activa, respuestas y puntajes.
///
/// notStarted → instructions → inProgress → sectionCompleted ⇄ inProgress
///                                                            ↘ finished
class ExamSessionNotifier extends Notifier<ExamSession> {
  late final ExamRepository _repo;
  late final ExamTimerService _timer;

  final _startExam = const StartExam();
  final _advanceSection = const AdvanceSection();
  final _submitAnswer = const SubmitAnswer();

  @override
  ExamSession build() {
    _repo = ref.watch(examRepositoryProvider);
    _timer = ref.watch(examTimerServiceProvider);

    _timer.onTick = (section, global) {
      ref.read(timerStateProvider.notifier).state = TimerState(
        sectionRemaining: section,
        globalRemaining: global,
      );
    };

    _timer.onSectionExpired = _onSectionTimeExpired;

    return ExamSession(
      examId: '',
      phase: ExamPhase.notStarted,
      activeSectionIndex: 0,
    );
  }

  // ─── Transiciones de estado ──────────────────────────────────────────────

  /// notStarted → instructions (primera sección: Listening)
  Future<void> startExam() async {
    try {
      final examId = await ref.read(examLocalDataSourceProvider).getExamId();
      final session = _startExam(examId: examId);
      final firstSection = ExamConstants.sectionOrder[0];
      final sectionDuration = ExamConstants.sectionDurations[firstSection]!;
      final sectionDeadline = DateTime.now().add(sectionDuration);

      state = session.copyWith(
        phase: ExamPhase.instructions,
        sectionEndsAt: sectionDeadline,
      );

      await _timer.start(
        sectionDeadline: sectionDeadline,
        globalDeadline: session.globalEndsAt!,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to start exam: $e');
    }
  }

  /// instructions → inProgress
  void beginSection() {
    if (state.phase != ExamPhase.instructions) return;
    state = state.copyWith(phase: ExamPhase.inProgress, clearError: true);
  }

  /// inProgress → sectionCompleted (por botón o tiempo agotado)
  Future<void> submitSection() async {
    if (state.phase != ExamPhase.inProgress) return;
    state = state.copyWith(phase: ExamPhase.sectionCompleted);
    await _scoreCurrentSection();
  }

  /// sectionCompleted → inProgress (siguiente sección) | finished
  Future<void> nextSection() async {
    if (state.phase != ExamPhase.sectionCompleted) return;

    final advanced = _advanceSection(current: state);
    state = advanced;

    if (advanced.phase == ExamPhase.finished) {
      await _timer.stop();
      return;
    }

    // Actualiza el deadline de sección en el servicio de temporizador.
    if (advanced.sectionEndsAt != null) {
      await _timer.updateSectionDeadline(advanced.sectionEndsAt!);
    }
  }

  /// Registra una respuesta sin cambiar de fase.
  void recordAnswer(Answer answer) {
    state = _submitAnswer(current: state, answer: answer);
  }

  /// Cancela el examen en curso y vuelve al estado inicial.
  Future<void> cancelExam() async {
    await _timer.stop();
    state = ExamSession(examId: '', phase: ExamPhase.notStarted, activeSectionIndex: 0);
  }

  // ─── Llamado por ExamTimerService cuando el tiempo de sección expira ────

  void _onSectionTimeExpired() {
    if (state.phase == ExamPhase.inProgress) {
      submitSection();
    }
  }

  // ─── Scoring ─────────────────────────────────────────────────────────────

  Future<void> _scoreCurrentSection() async {
    final section = state.activeSection;
    if (section == null) return;

    final sectionAnswers = state.answers.values
        .where((a) => a.questionId.startsWith(section.name[0].toUpperCase()))
        .toList();

    try {
      final score = await _repo.submitSectionForScoring(
        section: section,
        answers: sectionAnswers,
      );
      final updatedScores = Map<Section, SectionScore>.from(state.scores)
        ..[section] = score;
      state = state.copyWith(scores: updatedScores);
    } catch (e) {
      state = state.copyWith(
        scores: {
          ...state.scores,
          section: SectionScore(
            section: section,
            celpipBand: null,
          ),
        },
        errorMessage: 'Scoring unavailable: $e',
      );
    }
  }
}

/// Provider principal expuesto a toda la UI.
final examSessionProvider =
    NotifierProvider<ExamSessionNotifier, ExamSession>(
  ExamSessionNotifier.new,
);
