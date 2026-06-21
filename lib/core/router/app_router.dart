import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:celpip_simulator/features/exam_session/domain/entities/exam_session.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';
import 'package:celpip_simulator/features/exam_session/presentation/screens/dashboard_screen.dart';
import 'package:celpip_simulator/features/listening/presentation/screens/listening_screen.dart';
import 'package:celpip_simulator/features/reading/presentation/screens/reading_screen.dart';
import 'package:celpip_simulator/features/writing/presentation/screens/writing_screen.dart';
import 'package:celpip_simulator/features/speaking/presentation/screens/speaking_screen.dart';

/// Configuración central de go_router.
/// La navegación se guarda para redirigir automáticamente según el estado del examen.
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _ExamSessionListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = ref.read(examSessionProvider);
      final location = state.uri.toString();

      // Si el examen terminó, redirige al dashboard para mostrar resultados.
      if (session.phase == ExamPhase.finished && location != '/') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/listening',
        builder: (_, __) => const ListeningScreen(),
      ),
      GoRoute(
        path: '/reading',
        builder: (_, __) => const ReadingScreen(),
      ),
      GoRoute(
        path: '/writing',
        builder: (_, __) => const WritingScreen(),
      ),
      GoRoute(
        path: '/speaking',
        builder: (_, __) => const SpeakingScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

/// Puente entre el estado de Riverpod y el refreshListenable de GoRouter.
class _ExamSessionListenable extends ChangeNotifier {
  _ExamSessionListenable(Ref ref) {
    ref.listen<ExamSession>(examSessionProvider, (_, __) => notifyListeners());
  }
}
