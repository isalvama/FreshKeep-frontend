import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  const ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  }) async {
    try {
      await remoteDataSource.deleteProduct(productId: productId);
      return const Right(unit);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  @override
  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  }) async {
    try {
      await remoteDataSource.deleteProducts(productIds: productIds);
      return const Right(unit);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  ProductFailure _mapDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;

    switch (status) {
      case 400:
        return ProductValidationFailure(
          detail ?? 'Some of these products no longer exist.',
        );
      case 401:
        return ProductUnauthorizedFailure(
          detail ?? 'Your session has expired. Please log in again.',
        );
      case 403:
        return ProductForbiddenFailure(
          detail ?? 'You are not allowed to perform this action.',
        );
      case 409:
        return ProductConflictFailure(
          detail ?? 'You are not a participant of this space.',
        );
      default:
        return ProductNetworkFailure(
          e.message ?? 'Network error. Please check your connection.',
        );
    }
  }
}
