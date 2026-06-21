import 'package:flutter/material.dart';
import 'package:celpip_simulator/features/writing/presentation/providers/writing_provider.dart';

/// Barra inferior de conteo de palabras con indicador visual de estado.
///
/// Estados:
///   tooShort  → rojo   "X / min words"
///   valid     → verde  "X words ✓"
///   approaching → naranja  "X / max words — almost at limit"
///   overLimit → rojo   "X / max words — over limit"
class WordCountBar extends StatelessWidget {
  const WordCountBar({
    super.key,
    required this.wordCount,
    required this.minWords,
    required this.maxWords,
    required this.status,
  });

  final int wordCount;
  final int minWords;
  final int maxWords;
  final WordCountStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _config(status);
    final progress = wordCount.clamp(0, maxWords) / maxWords;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: color.withOpacity(0.4))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                'Target: $minWords–$maxWords words',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  static (Color, IconData, String) _config(WordCountStatus s) {
    return switch (s) {
      WordCountStatus.tooShort => (
          Colors.red,
          Icons.short_text_rounded,
          'Too short — write more',
        ),
      WordCountStatus.valid => (
          Colors.green,
          Icons.check_circle_outline_rounded,
          'Good length',
        ),
      WordCountStatus.approaching => (
          Colors.orange,
          Icons.warning_amber_rounded,
          'Approaching word limit',
        ),
      WordCountStatus.overLimit => (
          Colors.red,
          Icons.error_outline_rounded,
          'Over word limit — shorten your response',
        ),
    };
  }
}
