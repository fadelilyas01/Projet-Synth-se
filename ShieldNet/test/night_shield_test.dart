import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/services/night_shield_service.dart';

void main() {
  group('NightShieldService Tests', () {
    test('Calcul de plage traversant minuit (22h00 à 07h00)', () {
      // 23h30 -> Dans la plage (nuit)
      final nightTime1 = DateTime(2026, 9, 17, 23, 30);
      expect(NightShieldNotifier.checkTimeInWindow(nightTime1, 22, 0, 7, 0), isTrue);

      // 03h15 -> Dans la plage (nuit après minuit)
      final nightTime2 = DateTime(2026, 9, 17, 3, 15);
      expect(NightShieldNotifier.checkTimeInWindow(nightTime2, 22, 0, 7, 0), isTrue);

      // 14h00 -> Hors de la plage (journée)
      final dayTime = DateTime(2026, 9, 17, 14, 0);
      expect(NightShieldNotifier.checkTimeInWindow(dayTime, 22, 0, 7, 0), isFalse);

      // 07h01 -> Juste après la fin de la plage
      final morningTime = DateTime(2026, 9, 17, 7, 1);
      expect(NightShieldNotifier.checkTimeInWindow(morningTime, 22, 0, 7, 0), isFalse);
    });

    test('Calcul de plage simple en journée (12h00 à 14h00)', () {
      final inSiesta = DateTime(2026, 9, 17, 13, 0);
      expect(NightShieldNotifier.checkTimeInWindow(inSiesta, 12, 0, 14, 0), isTrue);

      final outSiesta = DateTime(2026, 9, 17, 15, 0);
      expect(NightShieldNotifier.checkTimeInWindow(outSiesta, 12, 0, 14, 0), isFalse);
    });
  });
}
