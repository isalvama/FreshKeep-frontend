part of 'space_overview_bloc.dart';

sealed class SpaceOverviewEvent {
  const SpaceOverviewEvent();
}

final class SpaceOverviewRequested extends SpaceOverviewEvent {
  final String spaceId;

  const SpaceOverviewRequested(this.spaceId);
}
