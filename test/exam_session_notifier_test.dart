import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:celpip_simulator/features/exam_session/data/datasources/exam_local_datasource.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';
import 'package:celpip_simulator/features/exam_session/domain/repositories/exam_repository.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeExamRepository implements ExamRepository {
  @override
  Future<List<Question>> getQuestionsForSection(Section section) async => [];

  @override
  Future<void> saveAnswer(Answer answer) async {}

  @override
  Future<SectionScore> submitSectionForScoring({
    required Section section,
    required List<Answer> answers,
  }) async =>
      SectionScore(section: section, rawScore: 80, celpipBand: '10');
}

class _FakeLocalDataSource implements ExamLocalDataSource {
  @override
  Future<String> getExamId() async => 'test-exam-001';

  @override
  Future<List<Question>> getQuestionsForSection(Section section) async => [];
}

// ─── Helper ──────────────────────────────────────────────────────────────────

Future<ProviderContainer> _makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      examRepositoryProvider.overrideWithValue(_FakeExamRepository()),
      examLocalDataSourceProvider.overrideWithValue(_FakeLocalDataSource()),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamSessionNotifier — state machine transitions', () {
    late ProviderContainer container;

    setUp(() async {
      container = await _makeContainer();
    });

    tearDown(() => container.dispose());

    test('initial state is notStarted', () {
      final session = container.read(examSessionProvider);
      expect(session.phase, ExamPhase.notStarted);
    });

    test('startExam() transitions to instructions with Listening section', () async {
      await container.read(examSessionProvider.notifier).startExam();
      final session = container.read(examSessionProvider);
      expect(session.phase, ExamPhase.instructions);
      expect(session.activeSection, Section.listening);
    });

    test('beginSection() moves from instructions to inProgress', () async {
      await container.read(examSessionProvider.notifier).startExam();
      container.read(examSessionProvider.notifier).beginSection();
      expect(container.read(examSessionProvider).phase, ExamPhase.inProgress);
    });

    test('submitSection() moves from inProgress to sectionCompleted', () async {
      await container.read(examSessionProvider.notifier).startExam();
      container.read(examSessionProvider.notifier).beginSection();
      await container.read(examSessionProvider.notifier).submitSection();
      expect(
        container.read(examSessionProvider).phase,
        ExamPhase.sectionCompleted,
      );
    });

    test('nextSection() advances to Reading and returns to instructions', () async {
      final notifier = container.read(examSessionProvider.notifier);
      await notifier.startExam();
      notifier.beginSection();
      await notifier.submitSection();
      await notifier.nextSection();

      final session = container.read(examSessionProvider);
      expect(session.phase, ExamPhase.instructions);
      expect(session.activeSection, Section.reading);
    });

    test('full cycle through all 4 sections ends in finished', () async {
      final notifier = container.read(examSessionProvider.notifier);
      await notifier.startExam();

      for (var i = 0; i < 4; i++) {
        notifier.beginSection();
        await notifier.submitSection();
        await notifier.nextSection();
      }

      expect(container.read(examSessionProvider).phase, ExamPhase.finished);
    });

    test('recordAnswer stores answer without changing phase', () async {
      final notifier = container.read(examSessionProvider.notifier);
      await notifier.startExam();
      notifier.beginSection();

      final answer = Answer(
        questionId: 'L1-Q1',
        content: const MultipleChoiceContent(selectedIndex: 1),
        answeredAt: DateTime.now(),
      );
      notifier.recordAnswer(answer);

      final session = container.read(examSessionProvider);
      expect(session.answers.containsKey('L1-Q1'), isTrue);
      expect(session.phase, ExamPhase.inProgress);
    });

    test('scores are populated after submitSection', () async {
      final notifier = container.read(examSessionProvider.notifier);
      await notifier.startExam();
      notifier.beginSection();
      await notifier.submitSection();

      final session = container.read(examSessionProvider);
      expect(session.scores[Section.listening], isNotNull);
      expect(session.scores[Section.listening]!.celpipBand, '10');
    });

    test('beginSection() is ignored when phase is not instructions', () async {
      // En notStarted, beginSection no debe cambiar la fase.
      container.read(examSessionProvider.notifier).beginSection();
      expect(
        container.read(examSessionProvider).phase,
        ExamPhase.notStarted,
      );
    });
  });
}
