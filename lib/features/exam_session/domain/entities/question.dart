import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';

/// Discriminador de comportamiento de UI y scoring para cada pregunta.
enum QuestionType {
  multipleChoice,
  writingEmail,
  writingSurvey,
  speakingTask,
}

/// Entidad rica que cubre los cuatro tipos de pregunta CELPIP.
/// Los campos opcionales sólo aplican al QuestionType correspondiente —
/// el modelo de datos valida su presencia en tiempo de parseo.
base class Question {
  const Question({
    required this.id,
    required this.section,
    required this.type,
    required this.prompt,
    required this.part,
    required this.partTitle,
    // Multiple choice (Listening / Reading)
    this.options,
    this.correctAnswerIndex,
    // Listening
    this.audioAsset,
    this.audioTranscript,
    // Reading
    this.passage,
    // Writing
    this.minWords,
    this.maxWords,
    this.timeMinutes,
    this.rubricHints,
    // Speaking
    this.prepSeconds,
    this.responseSeconds,
    this.imageAsset,
  });

  final String id;
  final Section section;
  final QuestionType type;
  final String prompt;
  final int part;
  final String partTitle;

  final List<String>? options;
  final int? correctAnswerIndex;

  final String? audioAsset;
  final String? audioTranscript;

  final String? passage;

  final int? minWords;
  final int? maxWords;
  final int? timeMinutes;
  final List<String>? rubricHints;

  final int? prepSeconds;
  final int? responseSeconds;
  final String? imageAsset;
}
