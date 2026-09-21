import '../../../../core/services/auth_service.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/repositories/admin_repository.dart';

/// Implémentation concrète du dépôt d'administration
/// Délègue les appels réseau à l'AuthService existant
class AdminRepositoryImpl implements AdminRepository {
  final AuthService _authService;

  const AdminRepositoryImpl({required AuthService authService})
      : _authService = authService;

  @override
  Future<AdminStats> getStats() async {
    final raw = await _authService.getAdminStats();
    return AdminStats.fromJson(raw);
  }

  @override
  Future<List<Map<String, dynamic>>> getBlacklist({
    String query = '',
    String filter = 'all',
    int page = 1,
    int limit = 50,
  }) {
    return _authService.getAdminBlacklist(
      query: query,
      filter: filter,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getReports() {
    return _authService.getAdminReports();
  }

  @override
  Future<List<Map<String, dynamic>>> getUsers() {
    return _authService.getAdminUsers();
  }

  @override
  Future<List<AuditLogEntry>> getAuditLogs() async {
    final rawLogs = await _authService.getAdminAuditLogs();
    return rawLogs.map((json) => AuditLogEntry.fromJson(json)).toList();
  }

  @override
  Future<String> moderateNumber({required String phoneHash, required String action}) {
    return _authService.moderateNumber(phoneHash: phoneHash, action: action);
  }

  @override
  Future<void> deleteNumber(String phoneHash) {
    return _authService.deleteAdminBlacklistNumber(phoneHash);
  }

  @override
  Future<void> deleteReport(String reportId) {
    return _authService.deleteAdminReport(reportId);
  }

  @override
  Future<void> addNumber({
    required String phoneNumber,
    required String category,
    required int riskScore,
    required bool isBlocked,
    required bool isWhitelisted,
  }) {
    return _authService.addAdminBlacklistNumber(
      phoneNumber: phoneNumber,
      category: category,
      riskScore: riskScore,
      isBlocked: isBlocked,
      isWhitelisted: isWhitelisted,
    );
  }

  @override
  Future<Map<String, dynamic>> purgeDatabase() {
    return _authService.purgeDatabase();
  }

  @override
  Future<Map<String, dynamic>> runConsensusAudit() {
    return _authService.runConsensusAudit();
  }

  @override
  Future<Map<String, dynamic>> getSyncStatus() {
    return _authService.getSyncStatus();
  }
}
