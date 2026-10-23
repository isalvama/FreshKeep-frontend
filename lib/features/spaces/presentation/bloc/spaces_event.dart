part of 'spaces_bloc.dart';

sealed class SpacesEvent {
  const SpacesEvent();
}

final class SpaceCreated extends SpacesEvent {
  final Space space;

  const SpaceCreated(this.space);
}

final class SpacesRequested extends SpacesEvent {
  const SpacesRequested();
}

/// Silent reload: never emits `loading`, and a failure keeps the current list.
final class SpacesRefreshed extends SpacesEvent {
  const SpacesRefreshed();
}
