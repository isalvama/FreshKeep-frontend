import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/product_changes.dart';
import '../../domain/entities/updated_product.dart';
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
      return Left(_mapDioException(e, _deleteValidationMessage));
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
      return Left(_mapDioException(e, _deleteValidationMessage));
    }
  }

  @override
  Future<Either<ProductFailure, UpdatedProduct>> updateProduct({
    required String productId,
    required ProductChanges changes,
  }) async {
    try {
      final model = await remoteDataSource.updateProduct(
        productId: productId,
        changes: changes,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e, _updateValidationMessage));
    }
  }

  static const _deleteValidationMessage =
      'Some of these products no longer exist.';
  static const _updateValidationMessage =
      "This product couldn't be updated. Check the values and try again.";

  /// [validationMessage] is the default for a 400 without `detail`.
  ProductFailure _mapDioException(DioException e, String validationMessage) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;

    switch (status) {
      case 400:
        return ProductValidationFailure(detail ?? validationMessage);
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
