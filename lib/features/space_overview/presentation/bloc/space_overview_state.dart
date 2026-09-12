part of 'space_overview_bloc.dart';

sealed class SpaceOverviewStatus {
  const SpaceOverviewStatus();
}

final class SpaceOverviewInitial extends SpaceOverviewStatus {
  const SpaceOverviewInitial();
}

final class SpaceOverviewLoading extends SpaceOverviewStatus {
  const SpaceOverviewLoading();
}

final class SpaceOverviewLoadSuccess extends SpaceOverviewStatus {
  final SpaceOverview overview;

  const SpaceOverviewLoadSuccess(this.overview);
}

final class SpaceOverviewLoadFailure extends SpaceOverviewStatus {
  final String message;

  const SpaceOverviewLoadFailure(this.message);
}

class SpaceOverviewState extends Equatable {
  final SpaceOverviewStatus status;

  const SpaceOverviewState({required this.status});

  factory SpaceOverviewState.initial() {
    return const SpaceOverviewState(status: SpaceOverviewInitial());
  }

  SpaceOverviewState copyWith({SpaceOverviewStatus? status}) {
    return SpaceOverviewState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}
