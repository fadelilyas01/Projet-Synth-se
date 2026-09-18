import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/blacklist_repository.dart';

class ReportSpamUseCase {
  final BlacklistRepository repository;

  ReportSpamUseCase(this.repository);

  Future<Either<Failure, bool>> call({
    required String rawPhoneNumber,
    required String category,
    String? comment,
  }) {
    if (rawPhoneNumber.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Veuillez renseigner un numéro valide.')));
    }
    if (category.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Veuillez sélectionner une catégorie.')));
    }

    return repository.submitSpamReport(
      rawPhoneNumber: rawPhoneNumber,
      category: category,
      comment: comment,
    );
  }
}
