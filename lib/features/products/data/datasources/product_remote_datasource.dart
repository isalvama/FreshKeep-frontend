import 'package:dio/dio.dart';

import '../../../shopping_receipt/data/datasources/shopping_receipt_remote_datasource.dart';
import '../../domain/entities/product_changes.dart';
import '../models/moved_product_response_model.dart';
import '../models/updated_product_response_model.dart';

class ProductRemoteDataSource {
  final Dio dio;

  const ProductRemoteDataSource(this.dio);

  /// `204 No Content` on success.
  Future<void> deleteProduct({required String productId}) async {
    await dio.delete('/api/v1/products/$productId');
  }

  /// `204 No Content` on success. All-or-nothing on the backend.
  Future<void> deleteProducts({required List<String> productIds}) async {
    await dio.delete('/api/v1/products', data: {'productsIds': productIds});
  }

  /// Partial update: only the non-null fields of [changes] are sent, since the
  /// backend treats a missing field as "keep the current value".
  Future<UpdatedProductResponseModel> updateProduct({
    required String productId,
    required ProductChanges changes,
  }) async {
    final response = await dio.patch(
      '/api/v1/products/$productId',
      data: {
        if (changes.name != null) 'name': changes.name,
        if (changes.expirationDate != null)
          'expirationDate': formatDateForRequest(changes.expirationDate!),
        if (changes.productType != null)
          'productType': changes.productType!.name,
        if (changes.amount != null) 'amount': changes.amount,
        if (changes.currency != null) 'currency': changes.currency!.name,
      },
    );

    return UpdatedProductResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// [oldStorageSpotId] must be the product's current spot; the backend
  /// recalculates the expiration date as part of the move.
  Future<MovedProductResponseModel> moveProduct({
    required String productId,
    required String oldStorageSpotId,
    required String newStorageSpotId,
  }) async {
    final response = await dio.patch(
      '/api/v1/products/$productId/storage-spot',
      data: {
        'oldStorageSpotId': oldStorageSpotId,
        'newStorageSpotId': newStorageSpotId,
      },
    );

    return MovedProductResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
