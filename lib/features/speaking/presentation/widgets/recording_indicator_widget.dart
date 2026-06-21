import 'package:flutter/material.dart';

/// Indicador visual animado (pulso rojo) cuando el micrófono está grabando.
///
/// Usa ScaleTransition con AnimationController para el efecto de latido.
/// Se dispone automáticamente al quitarse del árbol de widgets.
class RecordingIndicatorWidget extends StatefulWidget {
  const RecordingIndicatorWidget({super.key});

  @override
  State<RecordingIndicatorWidget> createState() =>
      _RecordingIndicatorWidgetState();
}

class _RecordingIndicatorWidgetState extends State<RecordingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 8, end: 24).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ScaleTransition(
          scale: _scale,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: _glow.value,
                  spreadRadius: _glow.value * 0.25,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        );
      },
    );
  }
}
