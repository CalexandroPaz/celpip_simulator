import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:celpip_simulator/features/speaking/presentation/providers/speaking_provider.dart';

/// Pantalla de estado de permiso de micrófono.
///
/// Cubre todo el contenido de la pantalla cuando el permiso no está concedido.
/// Muestra UI diferenciada para:
///   - unchecked        → spinner mientras se verifica
///   - denied           → botón "Grant Permission" para solicitar
///   - permanentlyDenied → botón "Open Settings" + explicación
class PermissionWidget extends ConsumerWidget {
  const PermissionWidget({super.key, required this.status});

  final MicPermission status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status == MicPermission.unchecked) {
      return const Center(child: CircularProgressIndicator());
    }

    final isPermanent = status == MicPermission.permanentlyDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermanent
                  ? Icons.mic_off_rounded
                  : Icons.mic_none_rounded,
              size: 72,
              color: isPermanent ? Colors.red.shade400 : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              isPermanent
                  ? 'Microphone permission denied'
                  : 'Microphone access required',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isPermanent
                  ? 'You have permanently denied microphone access. '
                    'Open device Settings and enable it under '
                    'App Permissions to continue the Speaking test.'
                  : 'CELPIP Speaking requires microphone access '
                    'to record your responses. Your recordings are '
                    'stored locally on this device.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (isPermanent)
              FilledButton.icon(
                onPressed: () =>
                    ref.read(speakingProvider.notifier).openDeviceSettings(),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open Settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  minimumSize: const Size(double.infinity, 48),
                ),
              )
            else
              FilledButton.icon(
                onPressed: () =>
                    ref.read(speakingProvider.notifier).requestPermission(),
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Grant Permission'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
