import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:celpip_simulator/core/router/app_router.dart';
import 'package:celpip_simulator/core/theme/app_theme.dart';

/// Raíz de la aplicación — conecta tema, router y ProviderScope.
class CelpipApp extends ConsumerWidget {
  const CelpipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CELPIP Simulator',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
