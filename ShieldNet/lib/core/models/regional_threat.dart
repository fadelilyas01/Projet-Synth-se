/// Modèle de données pour les renseignements sur les menaces téléphoniques régionales
/// (Spoofing et vagues d'attaques ciblées par indicatif régional).
class RegionalThreatSummary {
  final DateTime generatedAt;
  final int totalRegionsTracked;
  final List<RegionalThreatItem> regions;

  const RegionalThreatSummary({
    required this.generatedAt,
    required this.totalRegionsTracked,
    required this.regions,
  });

  factory RegionalThreatSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['regions'] as List?) ?? [];
    return RegionalThreatSummary(
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? '') ?? DateTime.now(),
      totalRegionsTracked: (json['total_regions_tracked'] as int?) ?? 0,
      regions: list
          .whereType<Map>()
          .map((e) => RegionalThreatItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Retourne la menace la plus critique s'il en existe une
  RegionalThreatItem? get highestAlert {
    if (regions.isEmpty) return null;
    try {
      return regions.firstWhere((r) => r.isCritical);
    } catch (_) {
      try {
        return regions.firstWhere((r) => r.isHigh);
      } catch (_) {
        return regions.first;
      }
    }
  }
}

class RegionalThreatItem {
  final String areaCode;
  final String regionName;
  final int totalSpams;
  final String topCategory;
  final int maxRiskScore;
  final String alertLevel;

  const RegionalThreatItem({
    required this.areaCode,
    required this.regionName,
    required this.totalSpams,
    required this.topCategory,
    required this.maxRiskScore,
    required this.alertLevel,
  });

  factory RegionalThreatItem.fromJson(Map<String, dynamic> json) {
    return RegionalThreatItem(
      areaCode: json['area_code']?.toString() ?? '',
      regionName: json['region_name']?.toString() ?? 'Région indéterminée',
      totalSpams: (json['total_spams'] as int?) ?? 0,
      topCategory: json['top_category']?.toString() ?? 'fraud',
      maxRiskScore: (json['max_risk_score'] as int?) ?? 0,
      alertLevel: json['alert_level']?.toString() ?? 'MODÉRÉ',
    );
  }

  bool get isCritical => alertLevel.toUpperCase().contains('CRITIQUE');
  bool get isHigh => alertLevel.toUpperCase().contains('ÉLEVÉ') || alertLevel.toUpperCase().contains('ELEVE');
}
