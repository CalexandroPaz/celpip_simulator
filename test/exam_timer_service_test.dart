import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celpip_simulator/core/services/exam_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamTimerService', () {
    late SharedPreferences prefs;
    late ExamTimerService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = ExamTimerService(prefs: prefs);
    });

    tearDown(() {
      service.cancelSync();
    });

    test('sectionRemaining returns zero before start', () {
      expect(service.sectionRemaining, Duration.zero);
    });

    test('sectionRemaining ≈ deadline minus now after start', () async {
      final deadline = DateTime.now().add(const Duration(minutes: 47));
      final globalDeadline = DateTime.now().add(const Duration(hours: 3));
      await service.start(
        sectionDeadline: deadline,
        globalDeadline: globalDeadline,
      );

      final remaining = service.sectionRemaining;
      // Permite 2 s de margen para ejecución del test.
      expect(remaining.inSeconds, greaterThan(47 * 60 - 2));
      expect(remaining.inSeconds, lessThanOrEqualTo(47 * 60));
    });

    test('persists deadline in SharedPreferences', () async {
      final deadline = DateTime.now().add(const Duration(minutes: 30));
      final globalDeadline = DateTime.now().add(const Duration(hours: 3));
      await service.start(
        sectionDeadline: deadline,
        globalDeadline: globalDeadline,
      );

      final stored = prefs.getString('section_deadline_iso');
      expect(stored, isNotNull);
      final parsed = DateTime.parse(stored!);
      expect(
        parsed.difference(deadline).abs().inSeconds,
        lessThan(1),
      );
    });

    test('tryRestoreFromStorage recovers a valid deadline', () async {
      final deadline = DateTime.now().add(const Duration(minutes: 20));
      final globalDeadline = DateTime.now().add(const Duration(hours: 3));

      // Simula una sesión previa guardada.
      await prefs.setString('section_deadline_iso', deadline.toIso8601String());
      await prefs.setString('global_deadline_iso', globalDeadline.toIso8601String());

      final restored = await service.tryRestoreFromStorage();
      expect(restored, isTrue);
      expect(service.sectionRemaining.inMinutes, closeTo(20, 1));
    });

    test('tryRestoreFromStorage returns false and fires onSectionExpired for expired deadline', () async {
      // Deadline en el pasado — simula que el examen expiró con la app cerrada.
      final expired = DateTime.now().subtract(const Duration(minutes: 5));
      final globalDeadline = DateTime.now().add(const Duration(hours: 1));
      await prefs.setString('section_deadline_iso', expired.toIso8601String());
      await prefs.setString('global_deadline_iso', globalDeadline.toIso8601String());

      bool expiredFired = false;
      service.onSectionExpired = () => expiredFired = true;

      final restored = await service.tryRestoreFromStorage();
      expect(restored, isFalse);
      expect(expiredFired, isTrue);
    });

    test('stop() clears SharedPreferences keys', () async {
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      final globalDeadline = DateTime.now().add(const Duration(hours: 3));
      await service.start(
        sectionDeadline: deadline,
        globalDeadline: globalDeadline,
      );
      await service.stop();

      expect(prefs.getString('section_deadline_iso'), isNull);
      expect(prefs.getString('global_deadline_iso'), isNull);
    });

    test('updateSectionDeadline updates persisted value', () async {
      final initial = DateTime.now().add(const Duration(minutes: 10));
      final globalDeadline = DateTime.now().add(const Duration(hours: 3));
      await service.start(
        sectionDeadline: initial,
        globalDeadline: globalDeadline,
      );

      final newDeadline = DateTime.now().add(const Duration(minutes: 55));
      await service.updateSectionDeadline(newDeadline);

      final stored = prefs.getString('section_deadline_iso')!;
      final parsed = DateTime.parse(stored);
      expect(parsed.difference(newDeadline).abs().inSeconds, lessThan(1));
      expect(service.sectionRemaining.inMinutes, closeTo(55, 1));
    });
  });
}
