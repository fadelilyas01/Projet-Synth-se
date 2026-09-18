import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NightShieldState {
  final bool isEnabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool isCurrentlyInNightWindow;

  const NightShieldState({
    required this.isEnabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.isCurrentlyInNightWindow,
  });

  NightShieldState copyWith({
    bool? isEnabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    bool? isCurrentlyInNightWindow,
  }) {
    return NightShieldState(
      isEnabled: isEnabled ?? this.isEnabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      isCurrentlyInNightWindow: isCurrentlyInNightWindow ?? this.isCurrentlyInNightWindow,
    );
  }
}

class NightShieldNotifier extends StateNotifier<NightShieldState> {
  static const String _keyEnabled = 'settings_night_shield_enabled';
  static const String _keyStartH = 'settings_night_start_h';
  static const String _keyStartM = 'settings_night_start_m';
  static const String _keyEndH = 'settings_night_end_h';
  static const String _keyEndM = 'settings_night_end_m';

  NightShieldNotifier()
      : super(const NightShieldState(
          isEnabled: false,
          startHour: 22,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
          isCurrentlyInNightWindow: false,
        )) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final startH = prefs.getInt(_keyStartH) ?? 22;
    final startM = prefs.getInt(_keyStartM) ?? 0;
    final endH = prefs.getInt(_keyEndH) ?? 7;
    final endM = prefs.getInt(_keyEndM) ?? 0;

    final inWindow = checkTimeInWindow(
      DateTime.now(),
      startH,
      startM,
      endH,
      endM,
    );

    state = NightShieldState(
      isEnabled: enabled,
      startHour: startH,
      startMinute: startM,
      endHour: endH,
      endMinute: endM,
      isCurrentlyInNightWindow: enabled && inWindow,
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    final inWindow = checkTimeInWindow(
      DateTime.now(),
      state.startHour,
      state.startMinute,
      state.endHour,
      state.endMinute,
    );
    state = state.copyWith(
      isEnabled: value,
      isCurrentlyInNightWindow: value && inWindow,
    );
  }

  Future<void> setSchedule({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStartH, startHour);
    await prefs.setInt(_keyStartM, startMinute);
    await prefs.setInt(_keyEndH, endHour);
    await prefs.setInt(_keyEndM, endMinute);

    final inWindow = checkTimeInWindow(
      DateTime.now(),
      startHour,
      startMinute,
      endHour,
      endMinute,
    );

    state = state.copyWith(
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      isCurrentlyInNightWindow: state.isEnabled && inWindow,
    );
  }

  static bool checkTimeInWindow(
    DateTime now,
    int startH,
    int startM,
    int endH,
    int endM,
  ) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startH * 60 + startM;
    final endMinutes = endH * 60 + endM;

    if (startMinutes < endMinutes) {
      // Plage normale en journée (ex: 13h00 à 17h00)
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Plage traversant minuit (ex: 22h00 à 07h00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }
}

final nightShieldProvider = StateNotifierProvider<NightShieldNotifier, NightShieldState>((ref) {
  return NightShieldNotifier();
});
