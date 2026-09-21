/// Modèle typé représentant les statistiques d'administration du serveur ShieldNet
class AdminStats {
  final int totalBlocked;
  final int totalWhitelisted;
  final int totalReports;
  final int totalUsers;
  final int totalSafeReports;
  final int totalAutoConsensus;
  final int totalBlacklisted;

  const AdminStats({
    required this.totalBlocked,
    required this.totalWhitelisted,
    required this.totalReports,
    required this.totalUsers,
    required this.totalSafeReports,
    required this.totalAutoConsensus,
    required this.totalBlacklisted,
  });

  /// Désérialise depuis la réponse JSON de l'API admin/stats/
  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalBlocked: json['total_blocked'] as int? ?? 0,
      totalWhitelisted: json['total_whitelisted'] as int? ?? 0,
      totalReports: json['total_reports'] as int? ?? 0,
      totalUsers: json['total_users'] as int? ?? 0,
      totalSafeReports: json['total_safe_reports'] as int? ?? 0,
      totalAutoConsensus: json['total_auto_consensus'] as int? ?? 0,
      totalBlacklisted: json['total_blacklisted'] as int? ?? 0,
    );
  }

  /// Convertit en Map pour compatibilité descendante avec les widgets existants
  Map<String, dynamic> toMap() => {
    'total_blocked': totalBlocked,
    'total_whitelisted': totalWhitelisted,
    'total_reports': totalReports,
    'total_users': totalUsers,
    'total_safe_reports': totalSafeReports,
    'total_auto_consensus': totalAutoConsensus,
    'total_blacklisted': totalBlacklisted,
  };
}
