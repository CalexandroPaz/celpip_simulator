import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:celpip_simulator/core/config/api_config.dart';
import 'package:celpip_simulator/features/exam_session/data/datasources/exam_remote_datasource.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';

// ─── Excepciones ─────────────────────────────────────────────────────────────

/// Error HTTP del servidor FastAPI.
final class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.body});
  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Respuesta con formato inesperado.
final class ApiParseException implements Exception {
  const ApiParseException(this.message);
  final String message;

  @override
  String toString() => 'ApiParseException: $message';
}

// ─── Cliente HTTP real ────────────────────────────────────────────────────────

/// Implementación del datasource remoto que llama al backend FastAPI.
///
/// ## Contrato de la API
///
/// ### Listening / Reading / Writing — POST /api/v1/score
/// ```
/// Content-Type: application/json
/// {
///   "section": "listening",
///   "answers": [
///     { "question_id": "L1-Q1", "type": "multipleChoice",
///       "selected_index": 2, "answered_at": "2026-06-20T10:00:00.000Z" },
///     { "question_id": "W1-Q1", "type": "text",
///       "text": "Dear...", "answered_at": "..." }
///   ]
/// }
/// ```
///
/// ### Speaking — POST /api/v1/score/speaking
/// ```
/// Content-Type: multipart/form-data
/// Field  "section":      "speaking"
/// Field  "answers_json": '[{"question_id":"S1","type":"audio",...},...]'
/// Files  "audio_<questionId>": <archivo .m4a>
/// ```
///
/// ### Respuesta común (200 OK)
/// ```json
/// {
///   "section": "listening",
///   "raw_score": 87.5,
///   "celpip_band": "10",
///   "pending": false
/// }
/// ```
/// Si la evaluación es asíncrona (Writing/Speaking sin IA disponible):
/// ```json
/// { "section": "speaking", "raw_score": null, "celpip_band": null, "pending": true }
/// ```
final class ExamRemoteDataSourceImpl implements ExamRemoteDataSource {
  ExamRemoteDataSourceImpl({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<SectionScore> submitSectionForScoring({
    required Section section,
    required List<Answer> answers,
  }) async {
    if (section == Section.speaking) {
      return _submitSpeaking(answers);
    }
    return _submitJson(section, answers);
  }

  // ─── JSON (Listening / Reading / Writing) ─────────────────────────────────

  Future<SectionScore> _submitJson(
    Section section,
    List<Answer> answers,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.scoreEndpoint}');

    final body = jsonEncode({
      'section': section.name,
      'answers': answers.map(_serializeAnswer).toList(),
    });

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: body,
          )
          .timeout(ApiConfig.jsonTimeout);
    } on Exception catch (e) {
      throw ApiException(statusCode: 0, body: 'Network error: $e');
    }

    _assertOk(response);
    return _parseScore(section, response.body);
  }

  // ─── Multipart (Speaking) ─────────────────────────────────────────────────

  Future<SectionScore> _submitSpeaking(List<Answer> answers) async {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.speakingScoreEndpoint}');

    final request = http.MultipartRequest('POST', uri)
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..fields['section'] = 'speaking'
      ..fields['answers_json'] = jsonEncode(
        answers.map(_serializeAnswer).toList(),
      );

    // Adjunta cada archivo de audio al formulario.
    for (final answer in answers) {
      final content = answer.content;
      if (content is! AudioContent) continue;

      final file = File(content.recordingPath);
      if (!file.existsSync()) continue; // Omite grabaciones fallidas.

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_${answer.questionId}',
          content.recordingPath,
          filename: '${answer.questionId}.m4a',
        ),
      );
    }

    late http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(ApiConfig.uploadTimeout);
    } on Exception catch (e) {
      throw ApiException(statusCode: 0, body: 'Upload error: $e');
    }

    final response = await http.Response.fromStream(streamed);
    _assertOk(response);
    return _parseScore(Section.speaking, response.body);
  }

  // ─── Serialización ────────────────────────────────────────────────────────

  Map<String, dynamic> _serializeAnswer(Answer a) {
    final base = <String, dynamic>{
      'question_id': a.questionId,
      'answered_at': a.answeredAt.toIso8601String(),
    };

    final extra = switch (a.content) {
      MultipleChoiceContent(:final selectedIndex) => {
          'type': 'multipleChoice',
          'selected_index': selectedIndex,
        },
      TextContent(:final text) => {
          'type': 'text',
          'text': text,
        },
      AudioContent(:final recordingPath) => {
          'type': 'audio',
          'recording_path': recordingPath,
        },
    };

    return {...base, ...extra};
  }

  // ─── Parsing y validación ─────────────────────────────────────────────────

  void _assertOk(http.Response response) {
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  SectionScore _parseScore(Section section, String body) {
    late Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiParseException('Response is not valid JSON');
    }

    return SectionScore(
      section: section,
      rawScore: (data['raw_score'] as num?)?.toDouble(),
      celpipBand: data['celpip_band'] as String?,
    );
  }
}
