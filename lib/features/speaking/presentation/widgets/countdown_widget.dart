import 'package:flutter/material.dart';

/// Muestra una cuenta regresiva circular con el tiempo restante en segundos.
///
/// Usado en dos fases del flujo Speaking:
///   - Preparación: color azul, label "PREPARATION"
///   - Respuesta:   color naranja, label "RECORDING"
class CountdownWidget extends StatelessWidget {
  const CountdownWidget({
    super.key,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.label,
    required this.color,
  });

  final int secondsRemaining;
  final int totalSeconds;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress =
        totalSeconds > 0 ? secondsRemaining / totalSeconds : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pista de fondo
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10,
                  color: color.withOpacity(0.12),
                ),
              ),
              // Progreso actual
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Segundos
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$secondsRemaining',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'sec',
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withOpacity(0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: color,
          ),
        ),
      ],
    );
  }
}
