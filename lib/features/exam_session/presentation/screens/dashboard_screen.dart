import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:celpip_simulator/core/constants/exam_constants.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/section.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';
import 'package:celpip_simulator/core/widgets/exam_exit_button.dart';

/// Pantalla principal del examen — muestra progresión, puntajes y controla
/// el inicio del flujo. Es el único punto de entrada al examen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _sectionRoutes = {
    Section.listening: '/listening',
    Section.reading: '/reading',
    Section.writing: '/writing',
    Section.speaking: '/speaking',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(examSessionProvider);
    final notifier = ref.read(examSessionProvider.notifier);

    // Navega automáticamente cuando la sección activa cambia a inProgress.
    ref.listen<ExamSession>(examSessionProvider, (prev, next) {
      if (next.phase == ExamPhase.inProgress && next.activeSection != null) {
        final route = _sectionRoutes[next.activeSection!];
        if (route != null && context.mounted) {
          context.go(route);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('CELPIP Advanced Simulator'),
        actions: [
          if (session.phase != ExamPhase.notStarted &&
              session.phase != ExamPhase.finished) ...[
            const _GlobalTimerChip(),
            const ExamExitButton(),
          ],
        ],
      ),
      body: switch (session.phase) {
        ExamPhase.notStarted => _NotStartedView(onStart: notifier.startExam),
        ExamPhase.instructions => _InstructionsView(
            session: session,
            onBegin: notifier.beginSection,
          ),
        ExamPhase.inProgress => const _InProgressPlaceholder(),
        ExamPhase.sectionCompleted => _SectionCompletedView(
            session: session,
            onNext: notifier.nextSection,
          ),
        ExamPhase.finished => _FinishedView(session: session),
      },
    );
  }
}

// ─── Sub-vistas ──────────────────────────────────────────────────────────────

class _NotStartedView extends StatelessWidget {
  const _NotStartedView({required this.onStart});
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, size: 80, color: Color(0xFF003B6F)),
            const SizedBox(height: 24),
            Text(
              'CELPIP-General\nAdvanced Practice Exam',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bands 9–12  ·  ${ExamConstants.sectionOrder.length} sections',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _SectionSummaryList(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Exam'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSummaryList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sections = ExamConstants.sectionOrder;
    return Column(
      children: sections.map((s) {
        final dur = ExamConstants.sectionDurations[s]!;
        return ListTile(
          leading: _sectionIcon(s),
          title: Text(s.displayName),
          trailing: Text('${dur.inMinutes} min'),
          dense: true,
        );
      }).toList(),
    );
  }

  Icon _sectionIcon(Section s) {
    return switch (s) {
      Section.listening => const Icon(Icons.headphones_rounded),
      Section.reading => const Icon(Icons.menu_book_rounded),
      Section.writing => const Icon(Icons.edit_rounded),
      Section.speaking => const Icon(Icons.mic_rounded),
    };
  }
}

class _InstructionsView extends StatelessWidget {
  const _InstructionsView({required this.session, required this.onBegin});
  final ExamSession session;
  final void Function() onBegin;

  @override
  Widget build(BuildContext context) {
    final section = session.activeSection;
    if (section == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.displayName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Time: ${ExamConstants.sectionDurations[section]!.inMinutes} minutes',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(height: 32),
          const Text(
            'Instructions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            _instructionsFor(section),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBegin,
              child: Text('Begin ${section.displayName}'),
            ),
          ),
        ],
      ),
    );
  }

  String _instructionsFor(Section s) {
    return switch (s) {
      Section.listening =>
        'You will hear each recording ONCE. You cannot pause, rewind, or replay. Answer the questions as you listen.',
      Section.reading =>
        'Read each passage carefully and answer the questions. You may review your answers within this section.',
      Section.writing =>
        'Complete both writing tasks. Aim for 150–200 words each. Manage your time across both tasks.',
      Section.speaking =>
        'You will have preparation time before each task, then recording begins automatically. Speak until time runs out. You cannot re-record.',
    };
  }
}

class _InProgressPlaceholder extends StatelessWidget {
  const _InProgressPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SectionCompletedView extends StatelessWidget {
  const _SectionCompletedView({required this.session, required this.onNext});
  final ExamSession session;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final section = session.activeSection;
    final score = section != null ? session.scores[section] : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '${section?.displayName ?? 'Section'} Completed',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (score?.celpipBand != null) ...[
              const SizedBox(height: 8),
              Text('Band: ${score!.celpipBand}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ] else ...[
              const SizedBox(height: 8),
              const Text('Score will be available after AI evaluation.'),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onNext,
              child: Text(session.isLastSection ? 'See Results' : 'Next Section'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.session});
  final ExamSession session;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Exam Complete', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Your results by section:'),
          const SizedBox(height: 16),
          ...ExamConstants.sectionOrder.map((s) {
            final score = session.scores[s];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: Text(s.displayName),
                subtitle: Text(score?.celpipBand != null
                    ? 'Band: ${score!.celpipBand}'
                    : 'Pending AI evaluation'),
                trailing: score?.rawScore != null
                    ? Text('${score!.rawScore!.toStringAsFixed(0)}%')
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Widget temporizador global (AppBar) ─────────────────────────────────────

class _GlobalTimerChip extends ConsumerWidget {
  const _GlobalTimerChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerStateProvider);
    final remaining = timer.globalRemaining;
    final hh = remaining.inHours.toString().padLeft(2, '0');
    final mm = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Chip(
        avatar: const Icon(Icons.timer_outlined, size: 16),
        label: Text('$hh:$mm:$ss'),
        backgroundColor: remaining.inMinutes < 10
            ? Colors.red.shade100
            : Colors.blue.shade100,
      ),
    );
  }
}
