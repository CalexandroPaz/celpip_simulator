import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';
import 'package:celpip_simulator/core/constants/exam_constants.dart';

/// Crea una sesión de examen nueva con fase inicial notStarted.
final class StartExam {
  const StartExam();

  ExamSession call({required String examId}) {
    final now = DateTime.now();
    return ExamSession(
      examId: examId,
      phase: ExamPhase.notStarted,
      activeSectionIndex: 0,
      globalEndsAt: now.add(ExamConstants.totalExamDuration),
    );
  }
}
