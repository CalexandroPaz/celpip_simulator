import 'package:flutter/material.dart';

/// Muestra el pasaje de lectura en una tarjeta con fondo diferenciado.
/// En CELPIP el candidato puede leer y releer el pasaje mientras responde.
class PassageCard extends StatefulWidget {
  const PassageCard({
    super.key,
    required this.passage,
    required this.partTitle,
  });

  final String passage;
  final String partTitle;

  @override
  State<PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<PassageCard> {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera colapsable
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.article_rounded,
                      size: 18, color: Color(0xFF003B6F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.partTitle,
                      style: const TextStyle(
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

          // Texto del pasaje (colapsable)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                widget.passage,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
