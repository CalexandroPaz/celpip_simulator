import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celpip_simulator/core/constants/exam_constants.dart';

/// Encapsula los temporizadores del examen (global + por sección).
///
/// DISEÑO CLAVE — deadline absoluto:
/// En lugar de decrementar un contador en memoria, persiste DateTime.toIso8601String()
/// en SharedPreferences. El tiempo restante siempre se calcula como
///   endsAt.difference(DateTime.now())
/// Esto garantiza que el tiempo siga transcurriendo aunque la app esté suspendida
/// (backgrounded, screen-off). El WidgetsBindingObserver recalcula al resumir.
///
/// El ticker de 1 s solo refresca la UI; nunca es la fuente de verdad del tiempo.
class ExamTimerService with WidgetsBindingObserver {
  ExamTimerService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  DateTime? _sectionDeadline;
  DateTime? _globalDeadline;

  Timer? _ticker;

  /// Callback que la UI o el notifier suscriben para recibir ticks cada segundo.
  void Function(Duration sectionRemaining, Duration globalRemaining)?
      onTick;

  /// Callback disparado cuando el tiempo de la sección llega a cero.
  void Function()? onSectionExpired;

  // ─── API pública ────────────────────────────────────────────────────────────

  /// Inicia (o reanuda) ambos temporizadores con los deadlines proporcionados.
  Future<void> start({
    required DateTime sectionDeadline,
    required DateTime globalDeadline,
  }) async {
    _sectionDeadline = sectionDeadline;
    _globalDeadline = globalDeadline;

    // Persiste los deadlines para sobrevivir a suspensiones del proceso.
    await _prefs.setString(
      ExamConstants.prefKeySectionDeadline,
      sectionDeadline.toIso8601String(),
    );
    await _prefs.setString(
      ExamConstants.prefKeyGlobalDeadline,
      globalDeadline.toIso8601String(),
    );

    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  /// Actualiza el deadline de sección al avanzar a la siguiente sección.
  Future<void> updateSectionDeadline(DateTime newDeadline) async {
    _sectionDeadline = newDeadline;
    await _prefs.setString(
      ExamConstants.prefKeySectionDeadline,
      newDeadline.toIso8601String(),
    );
  }

  /// Cancela el ticker y el observer de ciclo de vida de forma síncrona.
  /// Usar en ref.onDispose() donde no se puede awaitar.
  void cancelSync() {
    _ticker?.cancel();
    _ticker = null;
    WidgetsBinding.instance.removeObserver(this);
    _sectionDeadline = null;
    _globalDeadline = null;
  }

  /// Detiene completamente los temporizadores y limpia SharedPreferences (fin de examen).
  Future<void> stop() async {
    cancelSync();
    await _prefs.remove(ExamConstants.prefKeySectionDeadline);
    await _prefs.remove(ExamConstants.prefKeyGlobalDeadline);
  }

  /// Restaura los deadlines desde SharedPreferences tras un reinicio frío.
  Future<bool> tryRestoreFromStorage() async {
    final sectionRaw = _prefs.getString(ExamConstants.prefKeySectionDeadline);
    final globalRaw = _prefs.getString(ExamConstants.prefKeyGlobalDeadline);
    if (sectionRaw == null || globalRaw == null) return false;

    _sectionDeadline = DateTime.parse(sectionRaw);
    _globalDeadline = DateTime.parse(globalRaw);

    if (_sectionDeadline!.isBefore(DateTime.now())) {
      // El tiempo de sección ya expiró mientras la app estuvo cerrada.
      await stop();
      onSectionExpired?.call();
      return false;
    }

    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    return true;
  }

  Duration get sectionRemaining {
    if (_sectionDeadline == null) return Duration.zero;
    final r = _sectionDeadline!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  Duration get globalRemaining {
    if (_globalDeadline == null) return Duration.zero;
    final r = _globalDeadline!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver del segundo plano, recalcula contra el reloj real.
      // El ticker podría haber dejado de disparar durante la suspensión.
      _checkExpiry();
    }
  }

  // ─── Internos ────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _checkExpiry());
  }

  void _checkExpiry() {
    if (_sectionDeadline == null) return;

    final section = sectionRemaining;
    final global = globalRemaining;

    onTick?.call(section, global);

    if (section == Duration.zero) {
      stop();
      onSectionExpired?.call();
    }
  }
}
