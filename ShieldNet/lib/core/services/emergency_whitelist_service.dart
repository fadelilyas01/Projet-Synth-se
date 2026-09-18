import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../utils/logger.dart';

class EmergencyWhitelistState {
  final List<EmergencyContact> contacts;
  final bool isLoading;
  final String? errorMessage;

  const EmergencyWhitelistState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EmergencyWhitelistState copyWith({
    List<EmergencyContact>? contacts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EmergencyWhitelistState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EmergencyWhitelistNotifier extends StateNotifier<EmergencyWhitelistState> {
  final DatabaseHelper _dbHelper;

  EmergencyWhitelistNotifier([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        super(const EmergencyWhitelistState(isLoading: true)) {
    loadContacts();
  }

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final contacts = await _dbHelper.getAllEmergencyContacts();
      state = state.copyWith(contacts: contacts, isLoading: false);
    } catch (e) {
      AppLogger.log('[EmergencyWhitelist] Erreur chargement: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger la liste blanche: $e',
      );
    }
  }

  Future<bool> addContact({required String rawNumber, required String label}) async {
    try {
      await _dbHelper.addEmergencyContact(rawNumber, label);
      await loadContacts();
      return true;
    } catch (e) {
      AppLogger.log('[EmergencyWhitelist] Erreur ajout: $e');
      state = state.copyWith(errorMessage: 'Échec de l\'ajout du contact d\'urgence.');
      return false;
    }
  }

  Future<bool> removeContact(String phoneHash) async {
    try {
      final success = await _dbHelper.removeEmergencyContact(phoneHash);
      if (success) {
        await loadContacts();
      }
      return success;
    } catch (e) {
      AppLogger.log('[EmergencyWhitelist] Erreur suppression: $e');
      return false;
    }
  }

  Future<bool> isWhitelisted(String rawNumber) async {
    return await _dbHelper.isEmergencyNumber(rawNumber);
  }
}

final emergencyWhitelistProvider =
    StateNotifierProvider<EmergencyWhitelistNotifier, EmergencyWhitelistState>((ref) {
  return EmergencyWhitelistNotifier();
});
