import 'package:dio/dio.dart';

import '../../../spaces/domain/entities/storage_spot.dart';
import '../../domain/entities/product_extraction.dart';
import '../models/persisted_shopping_receipt_response_model.dart';
import '../models/receipt_extraction_response_model.dart';

class ShoppingReceiptRemoteDataSource {
  final Dio dio;

  const ShoppingReceiptRemoteDataSource(this.dio);

  Future<ReceiptExtractionResponseModel> processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
      'language': language,
    });

    final response = await dio.post(
      '/api/v1/spaces/$spaceId/receipt-images',
      data: formData,
    );

    return ReceiptExtractionResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PersistedShoppingReceiptResponseModel> confirmReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) async {
    final response = await dio.post(
      '/api/v1/spaces/$spaceId/shopping-receipt/confirm',
      data: {
        'receiptImageId': receiptImageId,
        'shoppingDate': formatDateForRequest(shoppingDate),
        'storeName': storeName,
        'allProducts': allProducts
            .map((product) => productRequestJson(product, spaceStorageSpots))
            .toList(),
      },
    );

    return PersistedShoppingReceiptResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<PersistedShoppingReceiptResponseModel> reprocessReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) async {
    final response = await dio.post(
      '/api/v1/spaces/$spaceId/shopping-receipt/reprocess',
      data: {
        'receiptImageId': receiptImageId,
        'shoppingDate': formatDateForRequest(shoppingDate),
        'storeName': storeName,
        'language': language,
        'flaggedProducts': flaggedProducts
            .map((product) => productRequestJson(product, spaceStorageSpots))
            .toList(),
        'allProducts': allProducts
            .map((product) => productRequestJson(product, spaceStorageSpots))
            .toList(),
      },
    );

    return PersistedShoppingReceiptResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}

/// Formats a [DateTime] as `yyyy-MM-dd`, the wire format every shopping-receipt
/// endpoint expects for date fields.
String formatDateForRequest(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Builds the `ProductRequest` JSON shape shared by confirm and reprocess.
/// `suggestedStorageSpotId` is required by the backend but nullable on
/// [ProductExtraction] (the AI may find no fitting spot) — falls back to the
/// space's first known storage spot when null.
Map<String, dynamic> productRequestJson(
  ProductExtraction product,
  List<StorageSpot> spaceStorageSpots,
) {
  return {
    'expirationDate': formatDateForRequest(product.expirationDate),
    'productName': product.productName,
    'suggestedStorageSpotId':
        product.suggestedStorageSpotId ?? spaceStorageSpots.first.id,
    'productType': product.productType,
    if (product.priceAmount != null) 'priceAmount': product.priceAmount,
    if (product.currency != null) 'currency': product.currency,
  };
}
