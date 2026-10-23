part of 'create_space_bloc.dart';

sealed class CreateSpaceEvent {
  const CreateSpaceEvent();
}

final class SpaceNameChanged extends CreateSpaceEvent {
  final String value;

  const SpaceNameChanged(this.value);
}

final class EmojiChanged extends CreateSpaceEvent {
  final String value;

  const EmojiChanged(this.value);
}

final class StorageSpotAdded extends CreateSpaceEvent {
  const StorageSpotAdded();
}

final class StorageSpotRemoved extends CreateSpaceEvent {
  final String key;

  const StorageSpotRemoved(this.key);
}

final class StorageSpotNameChanged extends CreateSpaceEvent {
  final String key;
  final String value;

  const StorageSpotNameChanged(this.key, this.value);
}

final class StorageSpotTypeChanged extends CreateSpaceEvent {
  final String key;
  final StorageSpotType value;

  const StorageSpotTypeChanged(this.key, this.value);
}

final class CreateSpaceSubmitted extends CreateSpaceEvent {
  const CreateSpaceSubmitted();
}

/// Restores the form to its default state. Dispatched after a successful
/// creation is acknowledged, or after the user confirms discarding changes —
/// never automatically, so an error retry keeps the entered data.
final class CreateSpaceReset extends CreateSpaceEvent {
  const CreateSpaceReset();
}
