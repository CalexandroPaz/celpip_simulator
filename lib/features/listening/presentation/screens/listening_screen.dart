import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';
import 'package:celpip_simulator/features/listening/presentation/providers/listening_provider.dart';
import 'package:celpip_simulator/features/listening/presentation/widgets/audio_indicator_widget.dart';
import 'package:celpip_simulator/core/widgets/multiple_choice_question_widget.dart';
import 'package:celpip_simulator/core/widgets/exam_exit_button.dart';

/// Módulo Listening — Fase 2 completa.
///
/// Flujo por part:
///   1. El audio arranca automáticamente (sin pausa ni retroceso).
///   2. Las preguntas se muestran de inmediato; el candidato puede responder
///      mientras escucha.
///   3. El botón "Next Part" / "Submit" permanece BLOQUEADO hasta que el audio
///      finaliza ([audioFinished] == true).
///   4. En modo dev (mp3 ausente) se muestra la transcripción y el estado
///      pasa a audioFinished al instante.
class ListeningScreen extends ConsumerStatefulWidget {
  const ListeningScreen({super.key});

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final questionsAsync =
        ref.watch(sectionQuestionsProvider(Section.listening));
    final listeningState = ref.watch(listeningProvider);
    final timer = ref.watch(timerStateProvider);

    // Inicialización one-shot cuando las preguntas están disponibles.
    if (!_initialized && questionsAsync.hasValue) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(listeningProvider.notifier)
              .initialize(questionsAsync.value!);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening'),
        automaticallyImplyLeading: false,
        actions: [_SectionTimerDisplay(remaining: timer.sectionRemaining), const ExamExitButton()],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (_) => _ListeningBody(
          state: listeningState,
          onSelectAnswer: (qId, idx) =>
              ref.read(listeningProvider.notifier).selectAnswer(qId, idx),
          onNextPart: () =>
              ref.read(listeningProvider.notifier).nextPart(),
          onSubmit: () async {
            await ref.read(listeningProvider.notifier).submitSection();
            if (context.mounted) context.go('/');
          },
        ),
      ),
    );
  }
}

// ─── Cuerpo principal ─────────────────────────────────────────────────────────

class _ListeningBody extends StatelessWidget {
  const _ListeningBody({
    required this.state,
    required this.onSelectAnswer,
    required this.onNextPart,
    required this.onSubmit,
  });

  final ListeningState state;
  final void Function(String questionId, int index) onSelectAnswer;
  final Future<void> Function() onNextPart;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    if (state.parts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final part = state.currentPart!;
    final totalParts = state.parts.length;
    final isLast = state.isLastPart;

    return Column(
      children: [
        // Barra de progreso de parts
        _PartProgressBar(
          current: state.currentPartIndex + 1,
          total: totalParts,
        ),

        // Indicador de audio (no expone controles de reproducción)
        AudioIndicatorWidget(
          isPlaying: state.isPlaying,
          audioFinished: state.audioFinished,
          isMockMode: state.isMockMode,
          transcript: part.audioTranscript,
          partNumber: part.partNumber,
          partTitle: part.partTitle,
        ),

        const Divider(height: 1),

        // Preguntas del part actual
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: part.questions.length,
            itemBuilder: (context, i) {
              final q = part.questions[i];
              return MultipleChoiceQuestionWidget(
                questionNumber: i + 1,
                prompt: q.prompt,
                options: q.options ?? [],
                selectedIndex: state.answers[q.id],
                enabled: !state.isSubmitting,
                onSelected: (idx) => onSelectAnswer(q.id, idx),
              );
            },
          ),
        ),

        // Barra de acción inferior
        _ActionBar(
          audioFinished: state.audioFinished,
          isSubmitting: state.isSubmitting,
          isLastPart: isLast,
          onNext: onNextPart,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ─── Barra de progreso de parts ───────────────────────────────────────────────

class _PartProgressBar extends StatelessWidget {
  const _PartProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
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
                valueColor: const AlwaysStoppedAnimation(Color(0xFF003B6F)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barra de acción inferior ─────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.audioFinished,
    required this.isSubmitting,
    required this.isLastPart,
    required this.onNext,
    required this.onSubmit,
  });

  final bool audioFinished;
  final bool isSubmitting;
  final bool isLastPart;
  final Future<void> Function() onNext;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aviso mientras el audio sigue reproduciendo
            if (!audioFinished)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_clock_rounded,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 6),
                    Text(
                      'Continue listening before advancing',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : isLastPart
                      ? ElevatedButton.icon(
                          onPressed: audioFinished ? onSubmit : null,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Submit Listening'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                audioFinished ? const Color(0xFF003B6F) : null,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: audioFinished ? onNext : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next Part'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                audioFinished ? const Color(0xFF003B6F) : null,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timer display ────────────────────────────────────────────────────────────

class _SectionTimerDisplay extends StatelessWidget {
  const _SectionTimerDisplay({required this.remaining});
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

// ─── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFB00020)),
            const SizedBox(height: 16),
            const Text(
              'Failed to load Listening questions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
