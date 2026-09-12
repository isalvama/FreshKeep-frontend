import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../entities/persisted_shopping_receipt.dart';
import '../entities/product_extraction.dart';
import '../repositories/shopping_receipt_repository.dart';

class ReprocessShoppingReceiptUseCase {
  final ShoppingReceiptRepository repository;

  const ReprocessShoppingReceiptUseCase(this.repository);

  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>> call({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => repository.reprocessReceipt(
    spaceId: spaceId,
    receiptImageId: receiptImageId,
    shoppingDate: shoppingDate,
    storeName: storeName,
    language: language,
    flaggedProducts: flaggedProducts,
    allProducts: allProducts,
    spaceStorageSpots: spaceStorageSpots,
  );
}
