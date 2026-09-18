import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/blacklisted_entry.dart';
import '../../domain/repositories/blacklist_repository.dart';
import '../../domain/usecases/get_blacklist_usecase.dart';
import '../../domain/usecases/sync_blacklist_usecase.dart';
import '../../domain/usecases/check_number_usecase.dart';
import '../../domain/usecases/report_spam_usecase.dart';
import '../../data/repositories/blacklist_repository_impl.dart';

// Providers d'injection de dépendances (Clean Architecture)
final blacklistRepositoryProvider = Provider<BlacklistRepository>((ref) {
  return BlacklistRepositoryImpl();
});

final getBlacklistUseCaseProvider = Provider<GetBlacklistUseCase>((ref) {
  return GetBlacklistUseCase(ref.watch(blacklistRepositoryProvider));
});

final syncBlacklistUseCaseProvider = Provider<SyncBlacklistUseCase>((ref) {
  return SyncBlacklistUseCase(ref.watch(blacklistRepositoryProvider));
});

final checkNumberUseCaseProvider = Provider<CheckNumberUseCase>((ref) {
  return CheckNumberUseCase(ref.watch(blacklistRepositoryProvider));
});

final reportSpamUseCaseProvider = Provider<ReportSpamUseCase>((ref) {
  return ReportSpamUseCase(ref.watch(blacklistRepositoryProvider));
});

// StateNotifier réactif pour la gestion d'état de la liste noire
class BlacklistNotifier extends StateNotifier<AsyncValue<List<BlacklistedEntry>>> {
  final GetBlacklistUseCase _getBlacklistUseCase;
  final SyncBlacklistUseCase _syncBlacklistUseCase;
  final BlacklistRepository _repository;

  BlacklistNotifier({
    required GetBlacklistUseCase getBlacklistUseCase,
    required SyncBlacklistUseCase syncBlacklistUseCase,
    required BlacklistRepository repository,
  })  : _getBlacklistUseCase = getBlacklistUseCase,
        _syncBlacklistUseCase = syncBlacklistUseCase,
        _repository = repository,
        super(const AsyncValue.loading()) {
    loadBlacklist();
  }

  Future<void> loadBlacklist() async {
    state = const AsyncValue.loading();
    final result = await _getBlacklistUseCase();
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (entries) => state = AsyncValue.data(entries),
    );
  }

  Future<int> syncWithServer() async {
    final result = await _syncBlacklistUseCase();
    return result.fold(
      (failure) {
        throw Exception(failure.message);
      },
      (count) {
        loadBlacklist();
        return count;
      },
    );
  }

  Future<int> clearCache() async {
    final result = await _repository.clearLocalCache();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (count) {
        state = const AsyncValue.data([]);
        return count;
      },
    );
  }
}

final blacklistControllerProvider =
    StateNotifierProvider<BlacklistNotifier, AsyncValue<List<BlacklistedEntry>>>((ref) {
  return BlacklistNotifier(
    getBlacklistUseCase: ref.watch(getBlacklistUseCaseProvider),
    syncBlacklistUseCase: ref.watch(syncBlacklistUseCaseProvider),
    repository: ref.watch(blacklistRepositoryProvider),
  );
});
