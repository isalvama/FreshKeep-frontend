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
