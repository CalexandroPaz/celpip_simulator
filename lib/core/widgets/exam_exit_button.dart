import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

/// Botón de cancelar examen para el AppBar de cualquier módulo.
/// Muestra un diálogo de confirmación antes de cancelar.
class ExamExitButton extends ConsumerWidget {
  const ExamExitButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.close_rounded),
      tooltip: 'Cancel exam',
      onPressed: () => _confirmExit(context, ref),
    );
  }

  Future<void> _confirmExit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel exam?'),
        content: const Text(
          'Your progress will be lost and the exam will not be scored. '
          'Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(examSessionProvider.notifier).cancelExam();
      if (context.mounted) context.go('/');
    }
  }
}
