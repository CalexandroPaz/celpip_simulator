import 'package:celpip_simulator/features/exam_session/data/datasources/exam_local_datasource.dart';
import 'package:celpip_simulator/features/exam_session/data/datasources/exam_remote_datasource.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section_score.dart';
import 'package:celpip_simulator/features/exam_session/domain/repositories/exam_repository.dart';

/// Implementación concreta del repositorio de examen.
/// Orquesta entre el datasource local (JSON) y el remoto (mock / FastAPI).
final class ExamRepositoryImpl implements ExamRepository {
  const ExamRepositoryImpl({
    required ExamLocalDataSource local,
    required ExamRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final ExamLocalDataSource _local;
  final ExamRemoteDataSource _remote;

  @override
  Future<List<Question>> getQuestionsForSection(Section section) =>
      _local.getQuestionsForSection(section);

  @override
  Future<void> saveAnswer(Answer answer) async {
    // En Fase 1 la persistencia local es en memoria (gestionada por el notifier).
    // En fases futuras, aquí se escribiría en Hive o se encolaría para sync.
  }

  @override
  Future<SectionScore> submitSectionForScoring({
    required Section section,
    required List<Answer> answers,
  }) =>
      _remote.submitSectionForScoring(section: section, answers: answers);
}
