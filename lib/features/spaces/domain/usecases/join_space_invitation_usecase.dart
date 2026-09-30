import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/space_repository.dart';

class JoinSpaceInvitationUseCase {
  final SpaceRepository repository;

  const JoinSpaceInvitationUseCase(this.repository);

  /// Returns the joined space's id.
  Future<Either<SpaceFailure, String>> call({required String token}) =>
      repository.joinInvitation(token: token);
}
