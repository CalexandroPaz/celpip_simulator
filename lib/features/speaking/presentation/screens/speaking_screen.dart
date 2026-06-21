import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';
import 'package:celpip_simulator/features/speaking/presentation/providers/speaking_provider.dart';
import 'package:celpip_simulator/features/speaking/presentation/widgets/countdown_widget.dart';
import 'package:celpip_simulator/features/speaking/presentation/widgets/permission_widget.dart';
import 'package:celpip_simulator/features/speaking/presentation/widgets/recording_indicator_widget.dart';

/// Módulo Speaking — Fase 4.
///
/// Flujo por tarea:
///   idle → [Start] → preparing (prepSeconds) → recording (responseSeconds) → submitted
///
/// Restricciones CELPIP:
///   - No re-grabación una vez submitted.
///   - La grabación se detiene automáticamente al expirar responseSeconds.
///   - nextTask() bloqueado hasta que la tarea actual esté submitted.
class SpeakingScreen extends ConsumerStatefulWidget {
  const SpeakingScreen({super.key});

  @override
  ConsumerState<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends ConsumerState<SpeakingScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final questionsAsync =
        ref.watch(sectionQuestionsProvider(Section.speaking));
    final speaking = ref.watch(speakingProvider);
    final timer = ref.watch(timerStateProvider);

    // Inicializa el notifier una sola vez tras cargar las preguntas.
    if (!_initialized && questionsAsync.hasValue) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(speakingProvider.notifier)
              .initialize(questionsAsync.value!);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speaking'),
        automaticallyImplyLeading: false,
        actions: [_SectionTimer(remaining: timer.sectionRemaining)],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading tasks: $e')),
        data: (_) {
          if (speaking.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Permiso no concedido — mostrar widget de permiso a pantalla completa.
          if (speaking.micPermission != MicPermission.granted) {
            return PermissionWidget(status: speaking.micPermission);
          }

          final task = speaking.currentTask!;

          return Column(
            children: [
              // Progreso de tareas
              _TaskProgressBar(
                current: speaking.currentTaskIndex + 1,
                total: speaking.tasks.length,
                partTitle: task.question.partTitle,
              ),

              // Error no fatal (ej. micrófono no disponible en emulador)
              if (speaking.errorMessage != null)
                _ErrorBanner(message: speaking.errorMessage!),

              // Contenido principal — desplazable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Imagen opcional (S3, S4, S8)
                      if (task.question.imageAsset != null)
                        _TaskImage(assetPath: task.question.imageAsset!),

                      // Prompt de la tarea
                      _PromptCard(
                        prompt: task.question.prompt,
                        rubricHints: task.question.rubricHints,
                        timeSeconds: task.question.responseSeconds,
                      ),

                      const SizedBox(height: 24),

                      // Widget de fase activa
                      _PhaseWidget(task: task),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Barra de navegación inferior
              _NavigationBar(
                state: speaking,
                onPrevious: () =>
                    ref.read(speakingProvider.notifier).previousTask(),
                onNext: () =>
                    ref.read(speakingProvider.notifier).nextTask(),
                onStart: () =>
                    ref.read(speakingProvider.notifier).startTask(),
                onSubmit: () async {
                  await ref
                      .read(speakingProvider.notifier)
                      .submitSection();
                  if (context.mounted) context.go('/');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Barra de progreso ────────────────────────────────────────────────────────

class _TaskProgressBar extends StatelessWidget {
  const _TaskProgressBar({
    required this.current,
    required this.total,
    required this.partTitle,
  });

  final int current;
  final int total;
  final String partTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Task $current of $total — $partTitle',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003B6F),
              ),
            ),
          ),
          // Puntos de progreso
          Row(
            children: List.generate(total, (i) {
              final Color color;
              if (i < current - 1) {
                color = Colors.green;
              } else if (i == current - 1) {
                color = const Color(0xFF003B6F);
              } else {
                color = Colors.grey.shade300;
              }
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Imagen de tarea ─────────────────────────────────────────────────────────

class _TaskImage extends StatelessWidget {
  const _TaskImage({required this.assetPath});
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB0C4DE)),
        color: const Color(0xFFF0F4F8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta de prompt ────────────────────────────────────────────────────────

class _PromptCard extends StatefulWidget {
  const _PromptCard({
    required this.prompt,
    this.rubricHints,
    this.timeSeconds,
  });

  final String prompt;
  final List<String>? rubricHints;
  final int? timeSeconds;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  const Icon(Icons.record_voice_over_rounded,
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
                  if (widget.timeSeconds != null)
                    Text(
                      '${widget.timeSeconds}s response',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  const SizedBox(width: 6),
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

          // Prompt expandible
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

// ─── Widget de fase ───────────────────────────────────────────────────────────

class _PhaseWidget extends StatelessWidget {
  const _PhaseWidget({required this.task});
  final SpeakingTask task;

  @override
  Widget build(BuildContext context) {
    return switch (task.phase) {
      SpeakingPhase.idle => _IdleView(task: task),
      SpeakingPhase.preparing => _PreparingView(task: task),
      SpeakingPhase.recording => _RecordingView(task: task),
      SpeakingPhase.submitted => const _SubmittedView(),
    };
  }
}

// ── Fase: idle ────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.task});
  final SpeakingTask task;

  @override
  Widget build(BuildContext context) {
    final prepSec = task.question.prepSeconds ?? 30;
    final respSec = task.question.responseSeconds ?? 60;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TimeChip(
              icon: Icons.hourglass_top_rounded,
              label: 'Prep',
              value: '${prepSec}s',
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(width: 12),
            _TimeChip(
              icon: Icons.mic_rounded,
              label: 'Response',
              value: '${respSec}s',
              color: Colors.orange.shade700,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Read the task, then press Start.\n'
          'Preparation will begin automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'You cannot re-record once your response is submitted.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.red,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fase: preparación ─────────────────────────────────────────────────────────

class _PreparingView extends StatelessWidget {
  const _PreparingView({required this.task});
  final SpeakingTask task;

  @override
  Widget build(BuildContext context) {
    final remaining = task.prepSecondsRemaining ?? 0;
    final total = task.question.prepSeconds ?? 30;

    return Column(
      children: [
        CountdownWidget(
          secondsRemaining: remaining,
          totalSeconds: total,
          label: 'PREPARATION',
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 16),
        const Text(
          'Organize your thoughts.\nRecording will start automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }
}

// ── Fase: grabación ───────────────────────────────────────────────────────────

class _RecordingView extends StatelessWidget {
  const _RecordingView({required this.task});
  final SpeakingTask task;

  @override
  Widget build(BuildContext context) {
    final remaining = task.responseSecondsRemaining ?? 0;
    final total = task.question.responseSeconds ?? 60;

    return Column(
      children: [
        const RecordingIndicatorWidget(),
        const SizedBox(height: 20),
        CountdownWidget(
          secondsRemaining: remaining,
          totalSeconds: total,
          label: 'RECORDING',
          color: Colors.orange.shade700,
        ),
        const SizedBox(height: 16),
        const Text(
          'Speak clearly into your microphone.\nThe recording stops automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }
}

// ── Fase: enviada ─────────────────────────────────────────────────────────────

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'Response submitted',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You cannot re-record this response.\nPress Next to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }
}

// ─── Banner de error ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 12, color: Colors.orange.shade800),
            ),
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
    required this.onPrevious,
    required this.onNext,
    required this.onStart,
    required this.onSubmit,
  });

  final SpeakingState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onStart;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final task = state.currentTask;
    final phase = task?.phase ?? SpeakingPhase.idle;
    final isActive = task?.isActive ?? false;

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
                  // Previous — deshabilitado durante grabación o prep activa
                  OutlinedButton.icon(
                    onPressed: (state.isFirstTask || isActive)
                        ? null
                        : onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Previous'),
                  ),

                  const Spacer(),

                  // Botón derecho según la fase actual
                  if (phase == SpeakingPhase.idle)
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Start'),
                    )
                  else if (isActive)
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: Text(
                        phase == SpeakingPhase.preparing
                            ? 'Preparing…'
                            : 'Recording…',
                      ),
                    )
                  else if (state.canSubmit)
                    FilledButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Submit Speaking'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: state.canGoNext ? onNext : null,
                      icon: const Icon(Icons.arrow_forward_rounded,
                          size: 18),
                      label: const Text('Next Task'),
                    ),
                ],
              ),
      ),
    );
  }
}

// ─── Timer de sección ─────────────────────────────────────────────────────────

class _SectionTimer extends StatelessWidget {
  const _SectionTimer({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final min =
        remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
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
