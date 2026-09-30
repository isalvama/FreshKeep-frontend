import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/product_changes.dart';
import '../entities/updated_product.dart';

abstract class ProductRepository {
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  });

  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  });

  Future<Either<ProductFailure, UpdatedProduct>> updateProduct({
    required String productId,
    required ProductChanges changes,
  });
}
