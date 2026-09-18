import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../network/api_service.dart';
import '../services/call_screening_service.dart';
export 'auth_provider.dart';

/// Provider pour le mode de thème (Clair / Sombre / Système)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Notifier pour la langue de l'application (Français par défaut ou Anglais)
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('settings_language') ?? 'fr';
      state = Locale(code);
    } catch (_) {}
  }

  Future<void> setLocale(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_language', languageCode);
      state = Locale(languageCode);
    } catch (_) {}
  }
}

/// Provider pour la langue de l'application
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Provider unique pour le client API ShieldNet
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Provider pour le service natif de filtrage d'appels
final callScreeningServiceProvider = Provider<CallScreeningService>((ref) => CallScreeningService());

/// Notifier pour l'état d'activation de la protection native Android
class ProtectionNotifier extends StateNotifier<AsyncValue<bool>> {
  final CallScreeningService _screeningService;

  ProtectionNotifier(this._screeningService) : super(const AsyncValue.loading()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userAutoBlock = prefs.getBool('settings_auto_block') ?? true;
      final userSms = prefs.getBool('settings_sms_analysis') ?? true;
      final nativeActive = await _screeningService.isCallScreeningActive();
      final phoneGranted = await Permission.phone.isGranted;

      // La protection sur l'accueil est active si les autorisations sont accordées
      // et que les fonctionnalités de filtrage (appels et SMS) sont activées.
      final isProtected = (nativeActive || phoneGranted) && userAutoBlock && userSms;
      state = AsyncValue.data(isProtected);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> requestPermission() async {
    state = const AsyncValue.loading();
    try {
      // 1. Demande d'autorisation téléphonique Android (READ_PHONE_STATE / CALLS)
      final phoneStatus = await Permission.phone.request();

      // 2. Demande de rôle CallScreeningService natif
      final roleGranted = await _screeningService.requestCallScreeningRole();

      // 3. Réactivation des préférences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_auto_block', true);
      await prefs.setBool('settings_sms_analysis', true);

      final isNowActive = roleGranted || phoneStatus.isGranted;
      state = AsyncValue.data(isNowActive);
      return isNowActive;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> updateAutoBlock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_block', enabled);
    await checkStatus();
  }

  Future<void> updateSmsAnalysis(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_sms_analysis', enabled);
    await checkStatus();
  }

  Future<void> disableProtection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_block', false);
    await prefs.setBool('settings_sms_analysis', false);
    state = const AsyncValue.data(false);
  }

  Future<void> toggleProtection() async {
    final current = state.value ?? false;
    if (current) {
      await disableProtection();
    } else {
      await requestPermission();
    }
  }
}

/// Provider pour observer le statut de protection globale
final protectionStatusProvider = StateNotifierProvider<ProtectionNotifier, AsyncValue<bool>>((ref) {
  return ProtectionNotifier(ref.watch(callScreeningServiceProvider));
});

/// Notifier pour le mode Contacts Uniquement (VIP Allowlist)
class ContactsOnlyNotifier extends StateNotifier<bool> {
  final CallScreeningService _service;

  ContactsOnlyNotifier(this._service) : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('settings_contacts_only') ?? false;
    } catch (_) {}
  }

  Future<bool> toggle(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_contacts_only', enabled);
      await _service.setContactsOnlyMode(enabled);
      state = enabled;
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Provider d'état pour le mode Contacts Uniquement
final contactsOnlyProvider = StateNotifierProvider<ContactsOnlyNotifier, bool>((ref) {
  return ContactsOnlyNotifier(ref.watch(callScreeningServiceProvider));
});

