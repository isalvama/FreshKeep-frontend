import '../../domain/entities/space.dart';

/// Passed via GoRouter's `extra` from the New Space form to the Status page.
sealed class CreateSpaceResult {
  const CreateSpaceResult();
}

class CreateSpaceResultSuccess extends CreateSpaceResult {
  final Space space;

  const CreateSpaceResultSuccess(this.space);
}

class CreateSpaceResultError extends CreateSpaceResult {
  final String message;

  const CreateSpaceResultError(this.message);
}
