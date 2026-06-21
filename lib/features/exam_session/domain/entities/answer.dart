import 'package:flutter/foundation.dart';

/// Contenido polimórfico de una respuesta según el tipo de pregunta.
@immutable
sealed class AnswerContent {
  const AnswerContent();
}

/// Respuesta de opción múltiple (Listening / Reading).
@immutable
final class MultipleChoiceContent extends AnswerContent {
  const MultipleChoiceContent({required this.selectedIndex});
  final int selectedIndex;
}

/// Respuesta de texto libre (Writing).
@immutable
final class TextContent extends AnswerContent {
  const TextContent({required this.text});
  final String text;
}

/// Respuesta de grabación de voz (Speaking).
@immutable
final class AudioContent extends AnswerContent {
  const AudioContent({required this.recordingPath});
  final String recordingPath;
}

/// Representa la respuesta del candidato a una pregunta específica.
@immutable
final class Answer {
  const Answer({
    required this.questionId,
    required this.content,
    required this.answeredAt,
  });

  final String questionId;
  final AnswerContent content;
  final DateTime answeredAt;
}
