import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';

/// Agrega o reemplaza una respuesta en la sesión activa.
final class SubmitAnswer {
  const SubmitAnswer();

  ExamSession call({required ExamSession current, required Answer answer}) {
    final updated = Map<String, Answer>.from(current.answers);
    updated[answer.questionId] = answer;
    return current.copyWith(answers: updated);
  }
}
