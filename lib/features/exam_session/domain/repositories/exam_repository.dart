import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';

/// Contrato de repositorio — el dominio solo conoce esta interfaz.
/// La implementación concreta vive en la capa data y es intercambiable.
abstract interface class ExamRepository {
  /// Carga todas las preguntas de una sección desde la fuente de datos activa.
  Future<List<Question>> getQuestionsForSection(Section section);

  /// Persiste una respuesta localmente (puede sincronizarse con el backend luego).
  Future<void> saveAnswer(Answer answer);

  /// Envía las respuestas de la sección al evaluador (mock local o FastAPI real).
  Future<SectionScore> submitSectionForScoring({
    required Section section,
    required List<Answer> answers,
  });
}
