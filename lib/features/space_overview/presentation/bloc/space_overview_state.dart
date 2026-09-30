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

sealed class ProductDeletionStatus {
  const ProductDeletionStatus();
}

final class ProductDeletionIdle extends ProductDeletionStatus {
  const ProductDeletionIdle();
}

final class ProductDeletionInProgress extends ProductDeletionStatus {
  const ProductDeletionInProgress();
}

final class ProductDeletionSuccess extends ProductDeletionStatus {
  final int deletedCount;

  const ProductDeletionSuccess(this.deletedCount);
}

final class ProductDeletionFailure extends ProductDeletionStatus {
  final String message;

  const ProductDeletionFailure(this.message);
}

class SpaceOverviewState extends Equatable {
  final SpaceOverviewStatus status;

  /// Empty when not in selection mode.
  final Set<String> selectedProductIds;
  final ProductDeletionStatus deletionStatus;

  const SpaceOverviewState({
    required this.status,
    this.selectedProductIds = const {},
    this.deletionStatus = const ProductDeletionIdle(),
  });

  factory SpaceOverviewState.initial() {
    return const SpaceOverviewState(status: SpaceOverviewInitial());
  }

  bool get isSelecting => selectedProductIds.isNotEmpty;

  SpaceOverviewState copyWith({
    SpaceOverviewStatus? status,
    Set<String>? selectedProductIds,
    ProductDeletionStatus? deletionStatus,
  }) {
    return SpaceOverviewState(
      status: status ?? this.status,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      deletionStatus: deletionStatus ?? this.deletionStatus,
    );
  }

  @override
  List<Object?> get props => [status, selectedProductIds, deletionStatus];
}
