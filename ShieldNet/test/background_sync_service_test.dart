import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/services/background_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundSyncService — Préférences de Synchronisation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isAutoSyncEnabled retourne true par défaut (aucune préférence sauvegardée)', () async {
      final enabled = await BackgroundSyncService.instance.isAutoSyncEnabled();
      expect(enabled, true);
    });

    test('setAutoSyncEnabled persiste la valeur et la relecture est cohérente', () async {
      await BackgroundSyncService.instance.setAutoSyncEnabled(false);
      final enabled = await BackgroundSyncService.instance.isAutoSyncEnabled();
      expect(enabled, false);

      await BackgroundSyncService.instance.setAutoSyncEnabled(true);
      final enabledAgain = await BackgroundSyncService.instance.isAutoSyncEnabled();
      expect(enabledAgain, true);
    });

    test('getSyncIntervalHours retourne 1 par défaut', () async {
      final hours = await BackgroundSyncService.instance.getSyncIntervalHours();
      expect(hours, 1);
    });

    test('setSyncIntervalHours persiste la valeur et la relecture est cohérente', () async {
      await BackgroundSyncService.instance.setSyncIntervalHours(6);
      final hours = await BackgroundSyncService.instance.getSyncIntervalHours();
      expect(hours, 6);
    });

    test('getLastSyncInfo retourne les valeurs par défaut quand aucune sync n\'a été effectuée', () async {
      final info = await BackgroundSyncService.instance.getLastSyncInfo();

      expect(info['lastSyncTime'], isNull);
      expect(info['lastSyncCount'], 0);
      expect(info['lastSyncStatus'], 'NONE');
    });

    test('getLastSyncInfo retourne les données correctes après une synchronisation simulée', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      await prefs.setString('last_sync_time', now);
      await prefs.setInt('last_sync_count', 42);
      await prefs.setString('last_sync_status', 'SUCCESS');

      final info = await BackgroundSyncService.instance.getLastSyncInfo();

      expect(info['lastSyncTime'], isNotNull);
      expect(info['lastSyncCount'], 42);
      expect(info['lastSyncStatus'], 'SUCCESS');
    });
  });
}
