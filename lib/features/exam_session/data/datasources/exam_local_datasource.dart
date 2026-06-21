import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:celpip_simulator/features/exam_session/data/models/question_model.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';

/// Carga el contenido del examen desde assets/exam_advanced.json.
/// El método getExamId() expone el identificador para inicializar ExamSession.
abstract interface class ExamLocalDataSource {
  Future<List<Question>> getQuestionsForSection(Section section);
  Future<String> getExamId();
}

final class ExamLocalDataSourceImpl implements ExamLocalDataSource {
  Map<String, dynamic>? _cached;

  Future<Map<String, dynamic>> _loadJson() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/exam_advanced.json');
    _cached = jsonDecode(raw) as Map<String, dynamic>;
    return _cached!;
  }

  @override
  Future<String> getExamId() async {
    final data = await _loadJson();
    return data['examId'] as String;
  }

  @override
  Future<List<Question>> getQuestionsForSection(Section section) async {
    final data = await _loadJson();
    final sections = data['sections'] as List<dynamic>;

    final sectionId = section.name; // enum name coincide con el campo "id" del JSON

    final sectionData = sections.firstWhere(
      (s) => (s as Map<String, dynamic>)['id'] == sectionId,
      orElse: () => throw ArgumentError('Section not found in JSON: $sectionId'),
    ) as Map<String, dynamic>;

    final questions = sectionData['questions'] as List<dynamic>;
    final parsed = questions
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
        .toList();
    return _shuffleByPart(parsed);
  }

  /// Agrupa las preguntas por número de part, mezcla el orden de los grupos
  /// y las aplana de vuelta. Así los audios y pasajes de lectura se mantienen
  /// intactos pero el orden de las partes varía en cada intento.
  List<Question> _shuffleByPart(List<Question> questions) {
    final groups = <int, List<Question>>{};
    for (final q in questions) {
      groups.putIfAbsent(q.part, () => []).add(q);
    }
    final partNumbers = groups.keys.toList()..shuffle(Random());
    return [for (final part in partNumbers) ...groups[part]!];
  }
}
