import 'package:shared_preferences/shared_preferences.dart';

/// Données formatées pour le widget d'écran d'accueil Android (AppWidget)
class HomeWidgetData {
  final bool isProtectionActive;
  final int blockedCountToday;
  final int totalBlockedInCache;
  final String lastSyncTimeFormatted;
  final String statusText;

  const HomeWidgetData({
    required this.isProtectionActive,
    required this.blockedCountToday,
    required this.totalBlockedInCache,
    required this.lastSyncTimeFormatted,
    required this.statusText,
  });

  Map<String, dynamic> toMap() {
    return {
      'is_protection_active': isProtectionActive,
      'blocked_count_today': blockedCountToday,
      'total_blocked_in_cache': totalBlockedInCache,
      'last_sync_formatted': lastSyncTimeFormatted,
      'status_text': statusText,
    };
  }
}

/// Service de synchronisation et de publication des données du Widget d'accueil Android
class HomeWidgetSyncService {
  static const String keyWidgetProtectionActive = 'widget_protection_active';
  static const String keyWidgetBlockedCount = 'widget_blocked_count';
  static const String keyWidgetTotalBlocked = 'widget_total_blocked';
  static const String keyWidgetLastSync = 'widget_last_sync';
  static const String keyWidgetStatusText = 'widget_status_text';

  /// Met à jour les valeurs partagées pour le widget Android natif
  static Future<void> updateWidgetData({
    required bool isProtectionActive,
    required int blockedCountToday,
    required int totalBlockedInCache,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final status = isProtectionActive ? 'BOUCLIER ACTIF' : 'PROTECTION SUSPENDUE';

      await prefs.setBool(keyWidgetProtectionActive, isProtectionActive);
      await prefs.setInt(keyWidgetBlockedCount, blockedCountToday);
      await prefs.setInt(keyWidgetTotalBlocked, totalBlockedInCache);
      await prefs.setString(keyWidgetLastSync, formattedTime);
      await prefs.setString(keyWidgetStatusText, status);
    } catch (_) {
      // Ignorer les erreurs non critiques de mise à jour du widget
    }
  }

  /// Lit l'état actuel des données du widget
  static Future<HomeWidgetData> getWidgetData() async {
    final prefs = await SharedPreferences.getInstance();
    return HomeWidgetData(
      isProtectionActive: prefs.getBool(keyWidgetProtectionActive) ?? true,
      blockedCountToday: prefs.getInt(keyWidgetBlockedCount) ?? 0,
      totalBlockedInCache: prefs.getInt(keyWidgetTotalBlocked) ?? 0,
      lastSyncTimeFormatted: prefs.getString(keyWidgetLastSync) ?? '--:--',
      statusText: prefs.getString(keyWidgetStatusText) ?? 'BOUCLIER ACTIF',
    );
  }
}
