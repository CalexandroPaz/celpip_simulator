import 'package:flutter/foundation.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';

/// Puntaje por sección. rawScore y celpipBand permanecen nulos hasta que
/// el backend de IA evalúe las respuestas de Writing y Speaking.
@immutable
final class SectionScore {
  const SectionScore({
    required this.section,
    this.rawScore,
    this.celpipBand,
  });

  final Section section;

  /// Puntaje numérico bruto (disponible inmediatamente para multipleChoice).
  final double? rawScore;

  /// Banda CELPIP (e.g. "10", "CLB 9") asignada por el evaluador de IA.
  final String? celpipBand;

  SectionScore copyWith({
    double? rawScore,
    String? celpipBand,
  }) {
    return SectionScore(
      section: section,
      rawScore: rawScore ?? this.rawScore,
      celpipBand: celpipBand ?? this.celpipBand,
    );
  }
}
