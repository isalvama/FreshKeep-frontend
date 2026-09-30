import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/product_changes.dart';
import '../entities/updated_product.dart';
import '../repositories/product_repository.dart';

class UpdateProductUseCase {
  final ProductRepository repository;

  const UpdateProductUseCase(this.repository);

  Future<Either<ProductFailure, UpdatedProduct>> call({
    required String productId,
    required ProductChanges changes,
  }) => repository.updateProduct(productId: productId, changes: changes);
}
