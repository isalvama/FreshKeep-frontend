import 'package:dio/dio.dart';

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
}
