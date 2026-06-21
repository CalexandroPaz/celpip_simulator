import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';
import 'package:celpip_simulator/features/writing/presentation/providers/writing_provider.dart';
import 'package:celpip_simulator/features/writing/presentation/widgets/word_count_bar.dart';
import 'package:celpip_simulator/core/widgets/exam_exit_button.dart';

/// Módulo Writing — Fase 3 completa.
///
/// Características:
///  - Dos tareas secuenciales (Email y Survey) con navegación libre.
///  - Un TextEditingController por tarea: el texto no se pierde al cambiar de tarea.
///  - Contador de palabras en tiempo real con indicadores de estado.
///  - Aviso visual cuando el candidato se acerca al límite o lo supera.
///  - El tiempo sugerido por tarea (27 / 26 min) se muestra como orientación;
///    el temporizador de sección (53 min total) es el que bloquea.
class WritingScreen extends ConsumerStatefulWidget {
  const WritingScreen({super.key});

  @override
  ConsumerState<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends ConsumerState<WritingScreen> {
  bool _initialized = false;

  /// Un controller por tarea; se crean con texto vacío y se actualizan
  /// desde el estado cuando se restaura una sesión.
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Devuelve (o crea) el TextEditingController asociado a una tarea.
  /// El listener propaga cambios al WritingNotifier cada keystroke.
  TextEditingController _controllerFor(WritingTask task) {
    final id = task.question.id;
    if (!_controllers.containsKey(id)) {
      final c = TextEditingController(text: task.text);
      c.addListener(() {
        ref.read(writingProvider.notifier).updateText(id, c.text);
      });
      _controllers[id] = c;
    }
    return _controllers[id]!;
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync =
        ref.watch(sectionQuestionsProvider(Section.writing));
    final writingState = ref.watch(writingProvider);
    final timer = ref.watch(timerStateProvider);

    if (!_initialized && questionsAsync.hasValue) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(writingProvider.notifier).initialize(questionsAsync.value!);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Writing'),
        automaticallyImplyLeading: false,
        actions: [_SectionTimer(remaining: timer.sectionRemaining), const ExamExitButton()],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error loading tasks: $e')),
        data: (_) {
          if (writingState.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final task = writingState.currentTask!;
          final controller = _controllerFor(task);

          return _WritingBody(
            state: writingState,
            task: task,
            controller: controller,
            onNext: () =>
                ref.read(writingProvider.notifier).nextTask(),
            onPrevious: () =>
                ref.read(writingProvider.notifier).previousTask(),
            onSubmit: () async {
              await ref.read(writingProvider.notifier).submitSection();
              if (context.mounted) context.go('/');
            },
          );
        },
      ),
    );
  }
}

// ─── Cuerpo principal ─────────────────────────────────────────────────────────

class _WritingBody extends StatelessWidget {
  const _WritingBody({
    required this.state,
    required this.task,
    required this.controller,
    required this.onNext,
    required this.onPrevious,
    required this.onSubmit,
  });

  final WritingState state;
  final WritingTask task;
  final TextEditingController controller;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final totalTasks = state.tasks.length;
    final currentIdx = state.currentTaskIndex + 1;

    return Column(
      children: [
        // Cabecera de progreso
        _TaskHeader(
          current: currentIdx,
          total: totalTasks,
          partTitle: task.question.partTitle,
          timeMinutes: task.question.timeMinutes,
        ),

        // Prompt de la tarea (desplazable, altura limitada)
        _PromptCard(
          prompt: task.question.prompt,
          rubricHints: task.question.rubricHints,
        ),

        // Editor de texto — ocupa el espacio restante
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              enabled: !state.isSubmitting,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: InputDecoration(
                hintText: 'Write your response here…',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFF003B6F), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),

        // Contador de palabras (sticky)
        WordCountBar(
          wordCount: task.wordCount,
          minWords: task.minWords,
          maxWords: task.maxWords,
          status: task.status,
        ),

        // Barra de navegación
        _NavigationBar(
          state: state,
          wordCount: task.wordCount,
          onPrevious: onPrevious,
          onNext: onNext,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ─── Cabecera ────────────────────────────────────────────────────────────────

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.current,
    required this.total,
    required this.partTitle,
    this.timeMinutes,
  });

  final int current;
  final int total;
  final String partTitle;
  final int? timeMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task $current of $total — $partTitle',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003B6F),
                  ),
                ),
                if (timeMinutes != null)
                  Text(
                    'Suggested time: $timeMinutes min',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          // Indicador visual de tarea
          Row(
            children: List.generate(total, (i) {
              final isDone = i < current - 1;
              final isCurrent = i == current - 1;
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? Colors.green
                      : isCurrent
                          ? const Color(0xFF003B6F)
                          : Colors.grey.shade300,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta de prompt ────────────────────────────────────────────────────────

class _PromptCard extends StatefulWidget {
  const _PromptCard({required this.prompt, this.rubricHints});
  final String prompt;
  final List<String>? rubricHints;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB0C4DE)),
      ),
      child: Column(
        children: [
          // Cabecera colapsable
          InkWell(
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.assignment_rounded,
                      size: 18, color: Color(0xFF003B6F)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Task instructions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003B6F),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF003B6F),
                  ),
                ],
              ),
            ),
          ),

          // Prompt + rubric hints
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.prompt,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                  if (widget.rubricHints != null &&
                      widget.rubricHints!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Scoring criteria:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A4A6A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...widget.rubricHints!.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    color: Color(0xFF4A4A6A))),
                            Expanded(
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4A4A6A),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ─── Barra de navegación ──────────────────────────────────────────────────────

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.state,
    required this.wordCount,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final WritingState state;
  final int wordCount;
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
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: state.isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: state.isFirstTask ? null : onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  if (state.isLastTask)
                    ElevatedButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Submit Writing'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Next Task'),
                    ),
                ],
              ),
      ),
    );
  }
}

// ─── Timer ─────────────────────────────────────────────────────────────────────

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
          Icon(Icons.timer_rounded,
              size: 16,
              color: isLow ? Colors.red.shade200 : Colors.white70),
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
