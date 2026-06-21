import 'package:flutter/material.dart';

/// Indicador visual del estado de reproducción de audio.
///
/// - [isPlaying]: anima un ícono pulsante para comunicar "reproduciendo".
/// - [audioFinished]: muestra un check verde.
/// - [isMockMode]: reemplaza el indicador por el texto de la transcripción.
///
/// NO expone controles de pausa/retroceso/barra de progreso — esto es
/// intencional: CELPIP solo permite escuchar una vez y sin interrupción.
class AudioIndicatorWidget extends StatefulWidget {
  const AudioIndicatorWidget({
    super.key,
    required this.isPlaying,
    required this.audioFinished,
    required this.isMockMode,
    this.transcript,
    required this.partNumber,
    required this.partTitle,
  });

  final bool isPlaying;
  final bool audioFinished;
  final bool isMockMode;
  final String? transcript;
  final int partNumber;
  final String partTitle;

  @override
  State<AudioIndicatorWidget> createState() => _AudioIndicatorWidgetState();
}

class _AudioIndicatorWidgetState extends State<AudioIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AudioIndicatorWidget old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera del part
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Part ${widget.partNumber} — ${widget.partTitle}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003B6F),
            ),
          ),
        ),

        // Indicador de audio
        if (widget.isMockMode)
          _TranscriptCard(transcript: widget.transcript)
        else if (widget.audioFinished)
          const _AudioFinishedBanner()
        else
          _PlayingBanner(pulse: _pulse),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PlayingBanner extends StatelessWidget {
  const _PlayingBanner({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF003B6F), width: 1.5),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: pulse,
            child: const Icon(
              Icons.volume_up_rounded,
              color: Color(0xFF003B6F),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Playing',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003B6F),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Listen carefully — you cannot replay this recording.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4A4A6A)),
                ),
              ],
            ),
          ),
          // ─ NO controles ─ (diseño intencional: examen CELPIP)
        ],
      ),
    );
  }
}

class _AudioFinishedBanner extends StatelessWidget {
  const _AudioFinishedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green, width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Text(
            'Audio complete. Answer the questions below.',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green),
          ),
        ],
      ),
    );
  }
}

/// Muestra la transcripción cuando el mp3 aún no existe en assets/.
class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({this.transcript});
  final String? transcript;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_snippet_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Transcript (audio not available in dev)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (transcript != null) ...[
            const SizedBox(height: 8),
            Text(
              transcript!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
