import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../entities/persisted_shopping_receipt.dart';
import '../entities/product_extraction.dart';
import '../repositories/shopping_receipt_repository.dart';

class ConfirmShoppingReceiptUseCase {
  final ShoppingReceiptRepository repository;

  const ConfirmShoppingReceiptUseCase(this.repository);

  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>> call({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => repository.confirmReceipt(
    spaceId: spaceId,
    shoppingReceiptId: shoppingReceiptId,
    receiptImageId: receiptImageId,
    shoppingDate: shoppingDate,
    storeName: storeName,
    allProducts: allProducts,
    spaceStorageSpots: spaceStorageSpots,
  );
}
