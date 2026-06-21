import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

// ─── Modelo de part ──────────────────────────────────────────────────────────

/// Agrupa preguntas que comparten el mismo pasaje de lectura.
/// El pasaje canónico se extrae de la primera pregunta que no es referencia cruzada.
@immutable
final class ReadingPart {
  const ReadingPart({
    required this.partNumber,
    required this.partTitle,
    this.passage,
    required this.questions,
  });

  final int partNumber;
  final String partTitle;

  /// Texto completo del pasaje. Null si todas las preguntas son referencias.
  final String? passage;
  final List<Question> questions;
}

// ─── Estado ──────────────────────────────────────────────────────────────────

/// Estado inmutable del módulo Reading.
/// La navegación entre parts es libre: el candidato puede ir hacia atrás
/// en cualquier momento y cambiar sus respuestas.
@immutable
final class ReadingState {
  const ReadingState({
    this.parts = const [],
    this.currentPartIndex = 0,
    this.answers = const {},
    this.isSubmitting = false,
  });

  final List<ReadingPart> parts;
  final int currentPartIndex;

  /// questionId → índice de opción seleccionada. Persiste al cambiar de part.
  final Map<String, int> answers;
  final bool isSubmitting;

  ReadingPart? get currentPart =>
      parts.isEmpty ? null : parts[currentPartIndex];

  bool get isLastPart => currentPartIndex >= parts.length - 1;
  bool get isFirstPart => currentPartIndex == 0;

  int get answeredCount => answers.length;

  int get totalQuestions =>
      parts.fold(0, (sum, p) => sum + p.questions.length);

  ReadingState copyWith({
    List<ReadingPart>? parts,
    int? currentPartIndex,
    Map<String, int>? answers,
    bool? isSubmitting,
  }) {
    return ReadingState(
      parts: parts ?? this.parts,
      currentPartIndex: currentPartIndex ?? this.currentPartIndex,
      answers: answers ?? this.answers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

/// Controlador del módulo Reading.
/// A diferencia de Listening, no hay bloqueo de avance: el candidato navega
/// libremente y puede cambiar respuestas en cualquier momento.
class ReadingNotifier extends Notifier<ReadingState> {
  @override
  ReadingState build() => const ReadingState();

  // ─── Init ─────────────────────────────────────────────────────────────

  void initialize(List<Question> questions) {
    state = ReadingState(parts: _groupIntoParts(questions));
  }

  // ─── Respuestas ────────────────────────────────────────────────────────

  void selectAnswer(String questionId, int selectedIndex) {
    final updated =
        Map<String, int>.from(state.answers)..[questionId] = selectedIndex;
    state = state.copyWith(answers: updated);

    ref.read(examSessionProvider.notifier).recordAnswer(
          Answer(
            questionId: questionId,
            content: MultipleChoiceContent(selectedIndex: selectedIndex),
            answeredAt: DateTime.now(),
          ),
        );
  }

  // ─── Navegación ────────────────────────────────────────────────────────

  void nextPart() {
    if (state.isLastPart) return;
    state = state.copyWith(currentPartIndex: state.currentPartIndex + 1);
  }

  void previousPart() {
    if (state.isFirstPart) return;
    state = state.copyWith(currentPartIndex: state.currentPartIndex - 1);
  }

  Future<void> submitSection() async {
    state = state.copyWith(isSubmitting: true);
    await ref.read(examSessionProvider.notifier).submitSection();
  }

  // ─── Agrupación por part ────────────────────────────────────────────────

  /// Agrupa preguntas por número de part y extrae el pasaje canónico.
  /// Las preguntas con "(Refer to...)" comparten el pasaje de la primera
  /// pregunta del part que tiene texto real.
  static List<ReadingPart> _groupIntoParts(List<Question> questions) {
    final Map<int, List<Question>> grouped = {};
    for (final q in questions) {
      grouped.putIfAbsent(q.part, () => []).add(q);
    }

    final sortedPartNums = grouped.keys.toList()..sort();

    return sortedPartNums.map((num) {
      final qs = grouped[num]!;

      // Pasaje canónico: primera pregunta cuyo passage no es referencia cruzada.
      final canonicalQ = qs.firstWhere(
        (q) =>
            q.passage != null &&
            !q.passage!.trimLeft().startsWith('(Refer'),
        orElse: () => qs.first,
      );

      return ReadingPart(
        partNumber: num,
        partTitle: qs.first.partTitle,
        passage: canonicalQ.passage,
        questions: qs,
      );
    }).toList();
  }
}

final readingProvider =
    NotifierProvider<ReadingNotifier, ReadingState>(ReadingNotifier.new);
