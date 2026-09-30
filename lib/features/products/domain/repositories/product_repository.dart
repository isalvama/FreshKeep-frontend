import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';

abstract class ProductRepository {
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  });

  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  });
}
