import '../entities/admin_stats.dart';
import '../entities/audit_log_entry.dart';

// Interface définissant les opérations de la console d'administration
abstract class AdminRepository {
  /// Récupère les statistiques globales du serveur
  Future<AdminStats> getStats();

  /// Récupère la liste noire paginée avec filtres
  Future<List<Map<String, dynamic>>> getBlacklist({
    String query,
    String filter,
    int page,
    int limit,
  });

  /// Récupère les signalements utilisateur en attente de modération
  Future<List<Map<String, dynamic>>> getReports();

  /// Récupère la liste des utilisateurs inscrits
  Future<List<Map<String, dynamic>>> getUsers();

  /// Récupère le journal d'audit avec traçabilité
  Future<List<AuditLogEntry>> getAuditLogs();

  /// Modère un numéro (bloquer ou blanchir)
  Future<String> moderateNumber({required String phoneHash, required String action});

  /// Supprime un numéro de la liste noire
  Future<void> deleteNumber(String phoneHash);

  /// Supprime un signalement
  Future<void> deleteReport(String reportId);

  /// Ajoute un numéro manuellement à la liste noire
  Future<void> addNumber({
    required String phoneNumber,
    required String category,
    required int riskScore,
    required bool isBlocked,
    required bool isWhitelisted,
  });

  /// Lance la purge de maintenance de la base de données
  Future<Map<String, dynamic>> purgeDatabase();

  /// Lance l'audit de consensualité automatique
  Future<Map<String, dynamic>> runConsensusAudit();

  /// Récupère le statut de synchronisation
  Future<Map<String, dynamic>> getSyncStatus();
}
