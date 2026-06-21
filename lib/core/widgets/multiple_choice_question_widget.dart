import 'package:flutter/material.dart';

/// Widget compartido para preguntas de opción múltiple.
/// Usado en Listening y Reading; el campo [passage] solo aplica a Reading.
///
/// - Resalta la opción seleccionada en azul con animación.
/// - [enabled] false bloquea la interacción (post-submit).
class MultipleChoiceQuestionWidget extends StatelessWidget {
  const MultipleChoiceQuestionWidget({
    super.key,
    required this.questionNumber,
    required this.prompt,
    required this.options,
    this.selectedIndex,
    required this.onSelected,
    this.enabled = true,
    this.passage,
  });

  final int questionNumber;
  final String prompt;
  final List<String> options;
  final int? selectedIndex;
  final void Function(int index) onSelected;
  final bool enabled;
  final String? passage;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question $questionNumber',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003B6F),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              prompt,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(options.length, (i) {
              return _OptionTile(
                label: String.fromCharCode(65 + i),
                text: options[i],
                isSelected: selectedIndex == i,
                enabled: enabled,
                onTap: enabled ? () => onSelected(i) : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final String text;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCEAFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF003B6F)
                : const Color(0xFFCCCCCC),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF003B6F)
                    : const Color(0xFFEEEEEE),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  color: enabled ? Colors.black87 : Colors.black38,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF003B6F),
              ),
          ],
        ),
      ),
    );
  }
}
