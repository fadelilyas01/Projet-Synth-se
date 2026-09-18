import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/providers/app_providers.dart';
import 'package:shieldnet/core/services/call_screening_service.dart';

class MockCallScreeningService extends CallScreeningService {
  bool nativeContactsOnly = false;

  @override
  Future<bool> setContactsOnlyMode(bool enabled) async {
    nativeContactsOnly = enabled;
    return true;
  }

  @override
  Future<bool> isContactsOnlyMode() async {
    return nativeContactsOnly;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mode Contacts Uniquement (VIP Allowlist) Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Le mode Contacts Uniquement est désactivé par défaut', () async {
      final mockService = MockCallScreeningService();
      final notifier = ContactsOnlyNotifier(mockService);

      expect(notifier.state, false);
    });

    test('L\'activation persiste dans SharedPreferences et synchronise avec le service natif', () async {
      final mockService = MockCallScreeningService();
      final notifier = ContactsOnlyNotifier(mockService);

      final success = await notifier.toggle(true);
      expect(success, true);
      expect(notifier.state, true);
      expect(mockService.nativeContactsOnly, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_contacts_only'), true);
    });

    test('La désactivation remet l\'état à false et synchronise avec le natif', () async {
      final mockService = MockCallScreeningService();
      final notifier = ContactsOnlyNotifier(mockService);

      await notifier.toggle(true);
      expect(notifier.state, true);

      await notifier.toggle(false);
      expect(notifier.state, false);
      expect(mockService.nativeContactsOnly, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_contacts_only'), false);
    });
  });
}
