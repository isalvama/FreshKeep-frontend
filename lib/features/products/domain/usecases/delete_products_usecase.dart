import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/product_repository.dart';

class DeleteProductsUseCase {
  final ProductRepository repository;

  const DeleteProductsUseCase(this.repository);

  Future<Either<ProductFailure, Unit>> call({
    required List<String> productIds,
  }) => repository.deleteProducts(productIds: productIds);
}
