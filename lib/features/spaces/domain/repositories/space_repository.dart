import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/space.dart';
import '../entities/storage_spot_input.dart';

abstract class SpaceRepository {
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  });

  Future<Either<SpaceFailure, List<Space>>> getUserSpaces();
}
