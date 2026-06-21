import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/core/constants/exam_constants.dart';

/// Avanza la sesión a la siguiente sección o termina el examen.
final class AdvanceSection {
  const AdvanceSection();

  ExamSession call({required ExamSession current}) {
    if (current.isLastSection) {
      return current.copyWith(phase: ExamPhase.finished);
    }

    final nextIndex = current.activeSectionIndex + 1;
    final nextSection = ExamConstants.sectionOrder[nextIndex];
    final duration = ExamConstants.sectionDurations[nextSection]!;

    return current.copyWith(
      phase: ExamPhase.instructions,
      activeSectionIndex: nextIndex,
      sectionEndsAt: DateTime.now().add(duration),
    );
  }
}
