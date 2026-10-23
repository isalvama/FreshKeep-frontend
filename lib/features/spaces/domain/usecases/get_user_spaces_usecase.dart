import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/space.dart';
import '../repositories/space_repository.dart';

class GetUserSpacesUseCase {
  final SpaceRepository repository;

  const GetUserSpacesUseCase(this.repository);

  Future<Either<SpaceFailure, List<Space>>> call() => repository.getUserSpaces();
}
