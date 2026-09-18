import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CitizenBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const CitizenBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}

class CitizenImpactData {
  final int reportsCount;
  final int protectedCitizensEstimate;
  final CitizenBadge currentRank;
  final List<CitizenBadge> allBadges;

  const CitizenImpactData({
    required this.reportsCount,
    required this.protectedCitizensEstimate,
    required this.currentRank,
    required this.allBadges,
  });
}

class CitizenImpactService {
  static const String _keyReportsCount = 'citizen_reports_count';

  static Future<int> getReportsCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReportsCount) ?? 0;
  }

  static Future<int> incrementReportsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyReportsCount) ?? 0;
    final next = current + 1;
    await prefs.setInt(_keyReportsCount, next);
    return next;
  }

  static Future<CitizenImpactData> getImpactData({int localBlockedSpams = 0}) async {
    final count = await getReportsCount();
    // Estimation d'impact communautaire
    final estimate = (count * 45) + (localBlockedSpams * 2);

    final badges = [
      CitizenBadge(
        id: 'vigie',
        title: 'Vigie Citoyenne',
        description: 'A soumis son tout premier signalement pour avertir la communauté.',
        icon: Icons.remove_red_eye_rounded,
        color: const Color(0xFF10B981),
        isUnlocked: count >= 1,
      ),
      CitizenBadge(
        id: 'sentinelle',
        title: 'Sentinelle Vigilante',
        description: 'A contribué avec au moins 5 signalements confirmés.',
        icon: Icons.shield_rounded,
        color: const Color(0xFF06B6D4),
        isUnlocked: count >= 5,
      ),
      CitizenBadge(
        id: 'gardien',
        title: 'Gardien d\'Élite',
        description: 'Pillier de la communauté ShieldNet avec plus de 10 fraudes neutralisées.',
        icon: Icons.military_tech_rounded,
        color: const Color(0xFFF59E0B),
        isUnlocked: count >= 10,
      ),
    ];

    CitizenBadge currentRank = badges.first;
    if (count >= 10) {
      currentRank = badges[2];
    } else if (count >= 5) {
      currentRank = badges[1];
    }

    return CitizenImpactData(
      reportsCount: count,
      protectedCitizensEstimate: estimate,
      currentRank: currentRank,
      allBadges: badges,
    );
  }
}
