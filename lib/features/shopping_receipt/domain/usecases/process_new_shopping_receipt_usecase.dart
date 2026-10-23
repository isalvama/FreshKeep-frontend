import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/receipt_extraction_result.dart';
import '../repositories/shopping_receipt_repository.dart';

class ProcessNewShoppingReceiptUseCase {
  final ShoppingReceiptRepository repository;

  const ProcessNewShoppingReceiptUseCase(this.repository);

  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>> call({
    required String spaceId,
    required String imagePath,
    required String language,
  }) => repository.processNewReceipt(
    spaceId: spaceId,
    imagePath: imagePath,
    language: language,
  );
}
