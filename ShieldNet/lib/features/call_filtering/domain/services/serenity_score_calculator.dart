import 'package:flutter/material.dart';

class SerenityRecommendation {
  final String title;
  final String description;
  final int scoreBonus;
  final IconData icon;
  final VoidCallback? onAction;

  const SerenityRecommendation({
    required this.title,
    required this.description,
    required this.scoreBonus,
    required this.icon,
    this.onAction,
  });
}

class SerenityScoreResult {
  final int score; // 0 à 100
  final String statusTitle;
  final Color statusColor;
  final List<SerenityRecommendation> recommendations;

  const SerenityScoreResult({
    required this.score,
    required this.statusTitle,
    required this.statusColor,
    required this.recommendations,
  });
}

class SerenityScoreCalculator {
  static SerenityScoreResult compute({
    required bool isCallScreeningActive,
    required bool isAutoBlockEnabled,
    required bool isBiometricEnabled,
    required bool isContactsOnlyEnabled,
    required bool isCacheFresh, // cache sync < 7 jours
  }) {
    int total = 0;
    final recs = <SerenityRecommendation>[];

    // 1. Filtrage d'appels natif (30 pts)
    if (isCallScreeningActive) {
      total += 30;
    } else {
      recs.add(const SerenityRecommendation(
        title: 'Activez le filtrage d\'appels natif',
        description: 'Bloque automatiquement les numéros malveillants avant que le téléphone ne sonne.',
        scoreBonus: 30,
        icon: Icons.phone_disabled_rounded,
      ));
    }

    // 2. Base hors-ligne à jour (20 pts)
    if (isCacheFresh) {
      total += 20;
    } else {
      recs.add(const SerenityRecommendation(
        title: 'Mettez à jour la base anti-spam',
        description: 'Téléchargez les derniers signalements pour rester protégé même sans réseau.',
        scoreBonus: 20,
        icon: Icons.sync_rounded,
      ));
    }

    // 3. Blocage automatique activé (20 pts)
    if (isAutoBlockEnabled) {
      total += 20;
    } else {
      recs.add(const SerenityRecommendation(
        title: 'Activez le blocage automatique',
        description: 'Rejette directement les arnaques avérées sans vous déranger.',
        scoreBonus: 20,
        icon: Icons.block_rounded,
      ));
    }

    // 4. Verrouillage biométrique (15 pts)
    if (isBiometricEnabled) {
      total += 15;
    } else {
      recs.add(const SerenityRecommendation(
        title: 'Sécurisez l\'accès par biométrie',
        description: 'Protégez vos listes blanches et données personnelles par empreinte ou visage.',
        scoreBonus: 15,
        icon: Icons.fingerprint_rounded,
      ));
    }

    // 5. Mode Contacts Uniquement (15 pts)
    if (isContactsOnlyEnabled) {
      total += 15;
    } else {
      recs.add(const SerenityRecommendation(
        title: 'Activez le mode Contacts Uniquement',
        description: 'Pour une sérénité totale, seuls vos contacts enregistrés peuvent faire sonner l\'appareil.',
        scoreBonus: 15,
        icon: Icons.contact_phone_rounded,
      ));
    }

    // Calcul du titre et de la couleur
    String title;
    Color color;

    if (total >= 90) {
      title = 'Sérénité Maximale';
      color = const Color(0xFF10B981); // Emerald Green
    } else if (total >= 70) {
      title = 'Protection Élevée';
      color = const Color(0xFF06B6D4); // Cyan
    } else if (total >= 40) {
      title = 'Protection Partielle';
      color = const Color(0xFFF59E0B); // Amber
    } else {
      title = 'Appareil Vulnérable';
      color = const Color(0xFFEF4444); // Red
    }

    return SerenityScoreResult(
      score: total,
      statusTitle: title,
      statusColor: color,
      recommendations: recs,
    );
  }
}
