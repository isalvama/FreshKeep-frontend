import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/product_repository.dart';

class DeleteProductUseCase {
  final ProductRepository repository;

  const DeleteProductUseCase(this.repository);

  Future<Either<ProductFailure, Unit>> call({required String productId}) =>
      repository.deleteProduct(productId: productId);
}
