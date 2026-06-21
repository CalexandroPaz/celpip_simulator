import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';

/// Fuente única de verdad para todos los límites temporales y de contenido del examen.
abstract final class ExamConstants {
  /// Duración total máxima del examen completo.
  static const Duration totalExamDuration = Duration(hours: 3);

  /// Duración por sección, según la especificación oficial de CELPIP.
  static const Map<Section, Duration> sectionDurations = {
    Section.listening: Duration(minutes: 47),
    Section.reading: Duration(minutes: 55),
    Section.writing: Duration(minutes: 53),
    Section.speaking: Duration(minutes: 20),
  };

  /// Orden canónico de las secciones durante el examen.
  static const List<Section> sectionOrder = [
    Section.listening,
    Section.reading,
    Section.writing,
    Section.speaking,
  ];

  /// Límites de palabras para Writing en nivel avanzado.
  static const int writingMinWords = 150;
  static const int writingMaxWords = 200;

  /// Clave usada en SharedPreferences para persistir el deadline de sección activa.
  static const String prefKeySectionDeadline = 'section_deadline_iso';

  /// Clave usada en SharedPreferences para persistir el deadline global del examen.
  static const String prefKeyGlobalDeadline = 'global_deadline_iso';
}
