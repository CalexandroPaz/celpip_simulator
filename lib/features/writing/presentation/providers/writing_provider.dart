import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/answer.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/question.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

// ─── Helpers de conteo ───────────────────────────────────────────────────────

/// Cuenta palabras dividiendo por espacios en blanco.
int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

/// Clasifica el estado del contador de palabras respecto a los límites.
enum WordCountStatus { tooShort, valid, approaching, overLimit }

WordCountStatus wordCountStatus(int count, int min, int max) {
  if (count < min) return WordCountStatus.tooShort;
  if (count > max) return WordCountStatus.overLimit;
  if (count >= max - 15) return WordCountStatus.approaching;
  return WordCountStatus.valid;
}

// ─── Modelo de tarea ─────────────────────────────────────────────────────────

/// Representa una tarea de Writing con su texto actual.
@immutable
final class WritingTask {
  const WritingTask({
    required this.question,
    this.text = '',
  });

  final Question question;
  final String text;

  int get wordCount => countWords(text);

  int get minWords => question.minWords ?? 150;
  int get maxWords => question.maxWords ?? 200;

  WordCountStatus get status => wordCountStatus(wordCount, minWords, maxWords);

  WritingTask copyWith({String? text}) {
    return WritingTask(question: question, text: text ?? this.text);
  }
}

// ─── Estado ──────────────────────────────────────────────────────────────────

/// Estado inmutable del módulo Writing.
@immutable
final class WritingState {
  const WritingState({
    this.tasks = const [],
    this.currentTaskIndex = 0,
    this.isSubmitting = false,
  });

  final List<WritingTask> tasks;
  final int currentTaskIndex;
  final bool isSubmitting;

  WritingTask? get currentTask =>
      tasks.isEmpty ? null : tasks[currentTaskIndex];

  bool get isLastTask => currentTaskIndex >= tasks.length - 1;
  bool get isFirstTask => currentTaskIndex == 0;

  WritingState copyWith({
    List<WritingTask>? tasks,
    int? currentTaskIndex,
    bool? isSubmitting,
  }) {
    return WritingState(
      tasks: tasks ?? this.tasks,
      currentTaskIndex: currentTaskIndex ?? this.currentTaskIndex,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

/// Controlador del módulo Writing.
/// Gestiona el texto de cada tarea y lo propaga al ExamSessionNotifier.
class WritingNotifier extends Notifier<WritingState> {
  @override
  WritingState build() => const WritingState();

  void initialize(List<Question> questions) {
    final tasks = questions.map((q) => WritingTask(question: q)).toList();
    state = WritingState(tasks: tasks);
  }

  /// Actualiza el texto de la tarea activa y propaga al ExamSessionNotifier.
  void updateText(String questionId, String text) {
    final updatedTasks = state.tasks.map((t) {
      if (t.question.id == questionId) return t.copyWith(text: text);
      return t;
    }).toList();
    state = state.copyWith(tasks: updatedTasks);

    ref.read(examSessionProvider.notifier).recordAnswer(
          Answer(
            questionId: questionId,
            content: TextContent(text: text),
            answeredAt: DateTime.now(),
          ),
        );
  }

  void nextTask() {
    if (state.isLastTask) return;
    state = state.copyWith(currentTaskIndex: state.currentTaskIndex + 1);
  }

  void previousTask() {
    if (state.isFirstTask) return;
    state = state.copyWith(currentTaskIndex: state.currentTaskIndex - 1);
  }

  Future<void> submitSection() async {
    state = state.copyWith(isSubmitting: true);
    await ref.read(examSessionProvider.notifier).submitSection();
  }
}

final writingProvider =
    NotifierProvider<WritingNotifier, WritingState>(WritingNotifier.new);
