import '../../../spaces/data/models/storage_spot_response_model.dart';
import '../../domain/entities/receipt_extraction_result.dart';
import 'product_extraction_response_model.dart';

class ReceiptExtractionResponseModel {
  final String receiptImageId;
  final List<StorageSpotResponseModel> suggestedStorageSpots;
  final DateTime purchaseShoppingDate;
  final String storeName;
  final List<ProductExtractionResponseModel> productExtractions;
  final List<ProductExtractionResponseModel> flaggedProducts;

  const ReceiptExtractionResponseModel({
    required this.receiptImageId,
    required this.suggestedStorageSpots,
    required this.purchaseShoppingDate,
    required this.storeName,
    required this.productExtractions,
    required this.flaggedProducts,
  });

  factory ReceiptExtractionResponseModel.fromJson(Map<String, dynamic> json) {
    return ReceiptExtractionResponseModel(
      receiptImageId: json['receiptImageId'] as String,
      suggestedStorageSpots: (json['suggestedStorageSpots'] as List<dynamic>)
          .map(
            (spot) => StorageSpotResponseModel.fromJson(
              spot as Map<String, dynamic>,
            ),
          )
          .toList(),
      purchaseShoppingDate: DateTime.parse(
        json['purchaseShoppingDate'] as String,
      ),
      storeName: json['storeName'] as String,
      productExtractions: (json['productExtractions'] as List<dynamic>)
          .map(
            (product) => ProductExtractionResponseModel.fromJson(
              product as Map<String, dynamic>,
            ),
          )
          .toList(),
      flaggedProducts: (json['flaggedProducts'] as List<dynamic>)
          .map(
            (product) => ProductExtractionResponseModel.fromJson(
              product as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  ReceiptExtractionResult toEntity() {
    return ReceiptExtractionResult(
      receiptImageId: receiptImageId,
      suggestedStorageSpots: suggestedStorageSpots
          .map((spot) => spot.toEntity())
          .toList(),
      purchaseShoppingDate: purchaseShoppingDate,
      storeName: storeName,
      productExtractions: productExtractions
          .map((product) => product.toEntity())
          .toList(),
      flaggedProducts: flaggedProducts
          .map((product) => product.toEntity())
          .toList(),
    );
  }
}
