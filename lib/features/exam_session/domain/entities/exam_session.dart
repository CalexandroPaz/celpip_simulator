import 'package:flutter/foundation.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';

/// Fases de la máquina de estados del examen.
///
/// notStarted → instructions → inProgress → sectionCompleted ⇄ inProgress
///                                                           ↘ finished
enum ExamPhase {
  notStarted,
  instructions,
  inProgress,
  sectionCompleted,
  finished,
}

/// Estado global de la sesión de examen.
/// Es la única fuente de verdad; todos los módulos la observan a través del notifier.
@immutable
final class ExamSession {
  const ExamSession({
    required this.examId,
    required this.phase,
    required this.activeSectionIndex,
    this.globalEndsAt,
    this.sectionEndsAt,
    this.answers = const {},
    this.scores = const {},
    this.errorMessage,
  });

  final String examId;
  final ExamPhase phase;

  /// Índice en ExamConstants.sectionOrder — avanza con cada nextSection().
  final int activeSectionIndex;

  final DateTime? globalEndsAt;
  final DateTime? sectionEndsAt;

  final Map<String, Answer> answers;
  final Map<Section, SectionScore> scores;

  /// Mensaje de error no-fatal mostrable en la UI.
  final String? errorMessage;

  Section? get activeSection {
    if (activeSectionIndex < 0) return null;
    const sections = [
      Section.listening,
      Section.reading,
      Section.writing,
      Section.speaking,
    ];
    if (activeSectionIndex >= sections.length) return null;
    return sections[activeSectionIndex];
  }

  bool get isLastSection => activeSectionIndex >= 3;

  ExamSession copyWith({
    ExamPhase? phase,
    int? activeSectionIndex,
    DateTime? globalEndsAt,
    DateTime? sectionEndsAt,
    Map<String, Answer>? answers,
    Map<Section, SectionScore>? scores,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExamSession(
      examId: examId,
      phase: phase ?? this.phase,
      activeSectionIndex: activeSectionIndex ?? this.activeSectionIndex,
      globalEndsAt: globalEndsAt ?? this.globalEndsAt,
      sectionEndsAt: sectionEndsAt ?? this.sectionEndsAt,
      answers: answers ?? this.answers,
      scores: scores ?? this.scores,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
