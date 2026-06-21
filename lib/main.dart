import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celpip_simulator/app.dart';
import 'package:celpip_simulator/features/exam_session/presentation/providers/exam_session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Provee la instancia real de SharedPreferences.
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CelpipApp(),
    ),
  );
}
