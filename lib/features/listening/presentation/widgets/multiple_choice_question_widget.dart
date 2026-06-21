import 'package:flutter/material.dart';

/// Widget reutilizable para preguntas de opción múltiple (Listening y Reading).
///
/// - Muestra número de pregunta, enunciado y 4 opciones.
/// - Resalta la opción seleccionada en azul.
/// - [enabled] false bloquea la selección (post-submit).
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

  /// Si viene con texto de pasaje (Reading), se muestra antes del enunciado.
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
            // Número + enunciado
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

            // Pasaje de lectura (opcional — solo Reading)
            if (passage != null &&
                !passage!.startsWith('(Refer') &&
                passage!.length > 40) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  passage!,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],

            Text(
              prompt,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Opciones A / B / C / D
            ...List.generate(options.length, (i) {
              final isSelected = selectedIndex == i;
              return _OptionTile(
                label: String.fromCharCode(65 + i), // A, B, C, D
                text: options[i],
                isSelected: isSelected,
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
    final bg = isSelected ? const Color(0xFFDCEAFF) : Colors.transparent;
    final borderColor =
        isSelected ? const Color(0xFF003B6F) : const Color(0xFFCCCCCC);
    final textColor =
        enabled ? Colors.black87 : Colors.black38;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Círculo de letra
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
                style: TextStyle(fontSize: 14, color: textColor, height: 1.3),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: Color(0xFF003B6F)),
          ],
        ),
      ),
    );
  }
}
