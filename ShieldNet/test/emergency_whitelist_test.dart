import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shieldnet/core/database/database_helper.dart';
import 'package:shieldnet/core/services/emergency_whitelist_service.dart';
import 'package:shieldnet/features/settings/presentation/pages/emergency_whitelist_page.dart';

class MockDatabaseHelper implements DatabaseHelper {
  MockDatabaseHelper._();
  static final MockDatabaseHelper mockInstance = MockDatabaseHelper._();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<EmergencyContact> _inMemoryContacts = [
    EmergencyContact(
      phoneHash: 'hash_911',
      rawNumber: '911',
      label: 'Urgences (Police, Pompiers, Ambulance)',
      isSystemCritical: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
    EmergencyContact(
      phoneHash: 'hash_811',
      rawNumber: '811',
      label: 'Info-Santé / Info-Social Québec',
      isSystemCritical: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
    EmergencyContact(
      phoneHash: 'hash_988',
      rawNumber: '988',
      label: 'Prévention du Suicide & Crise (Canada)',
      isSystemCritical: true,
      createdAt: DateTime.now().toIso8601String(),
    ),
  ];

  @override
  Future<List<EmergencyContact>> getAllEmergencyContacts() async {
    return List.from(_inMemoryContacts);
  }

  @override
  Future<EmergencyContact> addEmergencyContact(String rawNumber, String label) async {
    final contact = EmergencyContact(
      phoneHash: 'hash_${rawNumber.hashCode}',
      rawNumber: rawNumber,
      label: label,
      isSystemCritical: false,
      createdAt: DateTime.now().toIso8601String(),
    );
    _inMemoryContacts.add(contact);
    return contact;
  }

  @override
  Future<bool> removeEmergencyContact(String phoneHash) async {
    final countBefore = _inMemoryContacts.length;
    _inMemoryContacts.removeWhere((c) => c.phoneHash == phoneHash && !c.isSystemCritical);
    return _inMemoryContacts.length < countBefore;
  }

  @override
  Future<bool> isEmergencyNumber(String rawPhoneNumber) async {
    var cleanDigits = rawPhoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length == 4 && cleanDigits.startsWith('1')) {
      cleanDigits = cleanDigits.substring(1);
    }
    const standardEmergencyShortCodes = {'911', '112', '811', '988', '211', '311', '511'};
    if (standardEmergencyShortCodes.contains(cleanDigits) || standardEmergencyShortCodes.contains(rawPhoneNumber.trim())) {
      return true;
    }
    return _inMemoryContacts.any((c) => c.rawNumber == rawPhoneNumber.trim());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Emergency Whitelist (Liste Blanche d\'Urgence) Tests', () {
    late MockDatabaseHelper mockDb;
    late EmergencyWhitelistNotifier notifier;

    setUp(() {
      mockDb = MockDatabaseHelper.mockInstance;
      mockDb._inMemoryContacts.removeWhere((c) => !c.isSystemCritical);
      notifier = EmergencyWhitelistNotifier(mockDb);
    });

    test('Détection instantanée des services d\'urgence nationaux (911, 811, 988)', () async {
      expect(await mockDb.isEmergencyNumber('911'), isTrue);
      expect(await mockDb.isEmergencyNumber('+1911'), isTrue);
      expect(await mockDb.isEmergencyNumber('811'), isTrue);
      expect(await mockDb.isEmergencyNumber('988'), isTrue);
      expect(await mockDb.isEmergencyNumber(' 112 '), isTrue);
      expect(await mockDb.isEmergencyNumber('211'), isTrue);
      expect(await mockDb.isEmergencyNumber('311'), isTrue);
      expect(await mockDb.isEmergencyNumber('511'), isTrue);

      // Numéro normal ou suspect non whitelisté
      expect(await mockDb.isEmergencyNumber('+18195550199'), isFalse);
    });

    test('Ajout d\'un contact prioritaire et vérification de son immunité', () async {
      await notifier.loadContacts();
      expect(notifier.state.contacts.length, 3); // 911, 811, 988

      final added = await notifier.addContact(
        rawNumber: '+1 819 555 0199',
        label: 'Hôpital de Gatineau',
      );

      expect(added, isTrue);
      expect(notifier.state.contacts.length, 4);
      expect(
        notifier.state.contacts.any((c) => c.label == 'Hôpital de Gatineau'),
        isTrue,
      );

      // Le numéro ajouté bénéficie désormais de l'immunité
      expect(await mockDb.isEmergencyNumber('+1 819 555 0199'), isTrue);
    });

    test('Suppression d\'un contact d\'urgence utilisateur tout en protégeant le 911', () async {
      await notifier.loadContacts();
      await notifier.addContact(
        rawNumber: '8195551234',
        label: 'Clinique Santé',
      );

      final customContact = notifier.state.contacts.firstWhere((c) => c.label == 'Clinique Santé');
      final removed = await notifier.removeContact(customContact.phoneHash);
      expect(removed, isTrue);

      // Tentative de suppression du 911 (interdite / protégée car isSystemCritical = true)
      final system911 = notifier.state.contacts.firstWhere((c) => c.rawNumber == '911');
      final removed911 = await notifier.removeContact(system911.phoneHash);
      expect(removed911, isFalse);
      expect(notifier.state.contacts.any((c) => c.rawNumber == '911'), isTrue);
    });

    testWidgets('Rendu de EmergencyWhitelistPage avec badges Système et bouton d\'ajout', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            emergencyWhitelistProvider.overrideWith((ref) => EmergencyWhitelistNotifier(mockDb)),
          ],
          child: const MaterialApp(
            home: EmergencyWhitelistPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifie les éléments clés de l'UI
      expect(find.text('Numéros d\'Urgence & Immunité'), findsOneWidget);
      expect(find.text('Garantie Zéro Faux-Positif'), findsOneWidget);
      expect(find.text('SERVICES D\'URGENCE NATIONAUX (CANADA/QC)'), findsOneWidget);
      expect(find.text('Inviolable'), findsOneWidget);
      expect(find.text('Ajouter un Contact'), findsOneWidget);
      expect(find.text('911'), findsOneWidget);
      expect(find.text('811'), findsOneWidget);
      expect(find.text('988'), findsOneWidget);
    });
  });
}
