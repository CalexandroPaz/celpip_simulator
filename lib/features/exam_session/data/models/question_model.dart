import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';

/// DTO que parsea el JSON de exam_advanced.json y expone entidades de dominio.
/// fromJson es tolerante a campos ausentes — solo falla si los requeridos faltan.
final class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.section,
    required super.type,
    required super.prompt,
    required super.part,
    required super.partTitle,
    super.options,
    super.correctAnswerIndex,
    super.audioAsset,
    super.audioTranscript,
    super.passage,
    super.minWords,
    super.maxWords,
    super.timeMinutes,
    super.rubricHints,
    super.prepSeconds,
    super.responseSeconds,
    super.imageAsset,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type'] as String);
    final section = _parseSection(json['section'] as String);

    final model = QuestionModel(
      id: json['id'] as String,
      section: section,
      type: type,
      prompt: json['prompt'] as String,
      part: json['part'] as int,
      partTitle: json['partTitle'] as String,
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      correctAnswerIndex: json['correctAnswerIndex'] as int?,
      audioAsset: json['audioAsset'] as String?,
      audioTranscript: json['audioTranscript'] as String?,
      passage: json['passage'] as String?,
      minWords: json['minWords'] as int?,
      maxWords: json['maxWords'] as int?,
      timeMinutes: json['timeMinutes'] as int?,
      rubricHints: (json['rubricHints'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      prepSeconds: json['prepSeconds'] as int?,
      responseSeconds: json['responseSeconds'] as int?,
      imageAsset: json['imageAsset'] as String?,
    );

    _validate(model);
    return model;
  }

  static Section _parseSection(String raw) {
    return switch (raw) {
      'listening' => Section.listening,
      'reading' => Section.reading,
      'writing' => Section.writing,
      'speaking' => Section.speaking,
      _ => throw FormatException('Unknown section: $raw'),
    };
  }

  static QuestionType _parseType(String raw) {
    return switch (raw) {
      'multipleChoice' => QuestionType.multipleChoice,
      'writingEmail' => QuestionType.writingEmail,
      'writingSurvey' => QuestionType.writingSurvey,
      'speakingTask' => QuestionType.speakingTask,
      _ => throw FormatException('Unknown questionType: $raw'),
    };
  }

  // Verifica invariantes por tipo para detectar JSONs malformados en dev.
  static void _validate(QuestionModel q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        assert(q.options != null, '${q.id}: options required for multipleChoice');
        assert(
          q.correctAnswerIndex != null,
          '${q.id}: correctAnswerIndex required for multipleChoice',
        );
      case QuestionType.writingEmail:
      case QuestionType.writingSurvey:
        assert(q.minWords != null, '${q.id}: minWords required for writing');
        assert(q.maxWords != null, '${q.id}: maxWords required for writing');
      case QuestionType.speakingTask:
        assert(q.prepSeconds != null, '${q.id}: prepSeconds required for speaking');
        assert(
          q.responseSeconds != null,
          '${q.id}: responseSeconds required for speaking',
        );
    }
  }
}
