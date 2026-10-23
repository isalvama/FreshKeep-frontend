import 'package:equatable/equatable.dart';

import '../../../spaces/domain/entities/storage_spot.dart';
import 'product_extraction.dart';

class ReceiptExtractionResult extends Equatable {
  final String shoppingReceiptId;
  final String receiptImageId;
  final List<StorageSpot> suggestedStorageSpots;
  final DateTime purchaseShoppingDate;
  final String storeName;
  final List<ProductExtraction> productExtractions;
  final List<ProductExtraction> flaggedProducts;

  const ReceiptExtractionResult({
    required this.shoppingReceiptId,
    required this.receiptImageId,
    required this.suggestedStorageSpots,
    required this.purchaseShoppingDate,
    required this.storeName,
    required this.productExtractions,
    required this.flaggedProducts,
  });

  @override
  List<Object?> get props => [
    shoppingReceiptId,
    receiptImageId,
    suggestedStorageSpots,
    purchaseShoppingDate,
    storeName,
    productExtractions,
    flaggedProducts,
  ];
}
