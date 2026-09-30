import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/moved_product.dart';
import '../repositories/product_repository.dart';

class MoveProductUseCase {
  final ProductRepository repository;

  const MoveProductUseCase(this.repository);

  Future<Either<ProductFailure, MovedProduct>> call({
    required String productId,
    required String oldStorageSpotId,
    required String newStorageSpotId,
  }) => repository.moveProduct(
    productId: productId,
    oldStorageSpotId: oldStorageSpotId,
    newStorageSpotId: newStorageSpotId,
  );
}
