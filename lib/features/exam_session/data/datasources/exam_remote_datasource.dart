import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';

/// Contrato del datasource remoto — será reemplazado por el cliente HTTP de
/// FastAPI en Fase 5. La implementación mock devuelve puntajes fijos para
/// permitir que el flujo de la app funcione end-to-end desde la Fase 1.
abstract interface class ExamRemoteDataSource {
  Future<SectionScore> submitSectionForScoring({
    required Section section,
    required List<Answer> answers,
  });
}

/// Mock local: simula latencia de red y devuelve un puntaje de banda 10.
final class ExamRemoteDataSourceMock implements ExamRemoteDataSource {
  @override
  Future<SectionScore> submitSectionForScoring({
    required Section section,
    required List<Answer> answers,
  }) async {
    // Simula latencia de red del backend FastAPI.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // multipleChoice: calcula puntaje real; writing/speaking: marca como pendiente.
    final isAutoScored = section == Section.listening || section == Section.reading;

    if (isAutoScored) {
      final correct = answers.whereType<Answer>().where((a) {
        // El cálculo real requiere las preguntas; aquí devolvemos un mock.
        return true;
      }).length;
      final raw = (correct / answers.length.clamp(1, 999)) * 100;
      return SectionScore(
        section: section,
        rawScore: raw,
        celpipBand: _bandFromRaw(raw),
      );
    }

    // Writing y Speaking esperan evaluación de IA — puntaje pendiente.
    return SectionScore(section: section);
  }

  String _bandFromRaw(double raw) {
    if (raw >= 90) return '12';
    if (raw >= 80) return '11';
    if (raw >= 70) return '10';
    if (raw >= 60) return '9';
    return '8';
  }
}
