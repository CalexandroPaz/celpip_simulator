import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:celpip_simulator/core/widgets/multiple_choice_question_widget.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';
import 'package:celpip_simulator/features/reading/presentation/providers/reading_provider.dart';
import 'package:celpip_simulator/features/reading/presentation/widgets/passage_card.dart';
import 'package:celpip_simulator/core/widgets/exam_exit_button.dart';

/// Módulo Reading — Fase 3 completa.
///
/// Características:
///  - Preguntas agrupadas por part, cada una con su pasaje de lectura.
///  - El pasaje es colapsable para liberar espacio en pantalla.
///  - Navegación libre: Previous Part / Next Part sin restricciones.
///  - Las respuestas se preservan al navegar entre parts.
///  - "Submit Reading" disponible en cualquier moment desde el último part.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync =
        ref.watch(sectionQuestionsProvider(Section.reading));
    final readingState = ref.watch(readingProvider);
    final timer = ref.watch(timerStateProvider);

    // Inicialización one-shot.
    if (!_initialized && questionsAsync.hasValue) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(readingProvider.notifier).initialize(questionsAsync.value!);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading'),
        automaticallyImplyLeading: false,
        actions: [_SectionTimer(remaining: timer.sectionRemaining), const ExamExitButton()],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error loading questions: $e')),
        data: (_) {
          if (readingState.parts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ReadingBody(
            state: readingState,
            scrollController: _scrollController,
            onSelectAnswer: (qId, idx) {
              ref.read(readingProvider.notifier).selectAnswer(qId, idx);
            },
            onNext: () {
              ref.read(readingProvider.notifier).nextPart();
              _scrollController.jumpTo(0);
            },
            onPrevious: () {
              ref.read(readingProvider.notifier).previousPart();
              _scrollController.jumpTo(0);
            },
            onSubmit: () async {
              await ref.read(readingProvider.notifier).submitSection();
              if (context.mounted) context.go('/');
            },
          );
        },
      ),
    );
  }
}

// ─── Cuerpo principal ─────────────────────────────────────────────────────────

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({
    required this.state,
    required this.scrollController,
    required this.onSelectAnswer,
    required this.onNext,
    required this.onPrevious,
    required this.onSubmit,
  });

  final ReadingState state;
  final ScrollController scrollController;
  final void Function(String qId, int idx) onSelectAnswer;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final part = state.currentPart!;

    return Column(
      children: [
        // Barra de progreso + contador de respuestas
        _ProgressHeader(state: state),

        // Lista desplazable: pasaje + preguntas
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // Pasaje de lectura (colapsable)
              if (part.passage != null)
                PassageCard(
                  passage: part.passage!,
                  partTitle: part.partTitle,
                ),

              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Questions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003B6F),
                    letterSpacing: 0.4,
                  ),
                ),
              ),

              // Preguntas del part actual
              ...List.generate(part.questions.length, (i) {
                final q = part.questions[i];
                return MultipleChoiceQuestionWidget(
                  questionNumber: i + 1,
                  prompt: q.prompt,
                  options: q.options ?? [],
                  selectedIndex: state.answers[q.id],
                  enabled: !state.isSubmitting,
                  onSelected: (idx) => onSelectAnswer(q.id, idx),
                );
              }),
            ],
          ),
        ),

        // Barra de navegación inferior
        _NavigationBar(
          state: state,
          onPrevious: onPrevious,
          onNext: onNext,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ─── Barra de progreso ────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});
  final ReadingState state;

  @override
  Widget build(BuildContext context) {
    final total = state.parts.length;
    final current = state.currentPartIndex + 1;
    final answered = state.answeredCount;
    final totalQ = state.totalQuestions;

    return Container(
      color: const Color(0xFFF0F4F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Part $current of $total',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003B6F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: current / total,
                minHeight: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF003B6F)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$answered / $totalQ answered',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ─── Barra de navegación inferior ────────────────────────────────────────────

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final ReadingState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
        ),
        child: state.isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  // Previous Part
                  OutlinedButton.icon(
                    onPressed: state.isFirstPart ? null : onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  // Next Part or Submit
                  if (state.isLastPart)
                    ElevatedButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Submit Reading'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Next Part'),
                    ),
                ],
              ),
      ),
    );
  }
}

// ─── Timer ────────────────────────────────────────────────────────────────────

class _SectionTimer extends StatelessWidget {
  const _SectionTimer({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final min = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final isLow = remaining.inMinutes < 5;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          Icon(
            Icons.timer_rounded,
            size: 16,
            color: isLow ? Colors.red.shade200 : Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            '$min:$sec',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isLow ? Colors.red.shade200 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
