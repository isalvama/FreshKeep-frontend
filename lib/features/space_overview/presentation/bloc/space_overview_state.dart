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

sealed class ProductMoveStatus {
  const ProductMoveStatus();
}

final class ProductMoveIdle extends ProductMoveStatus {
  const ProductMoveIdle();
}

final class ProductMoveInProgress extends ProductMoveStatus {
  const ProductMoveInProgress();
}

final class ProductMoveSuccess extends ProductMoveStatus {
  final MoveDestination destination;
  final DateTime newExpirationDate;

  const ProductMoveSuccess({
    required this.destination,
    required this.newExpirationDate,
  });
}

final class ProductMoveFailure extends ProductMoveStatus {
  final String message;

  const ProductMoveFailure(this.message);
}

class SpaceOverviewState extends Equatable {
  final SpaceOverviewStatus status;

  /// Empty when not in selection mode.
  final Set<String> selectedProductIds;
  final ProductDeletionStatus deletionStatus;
  final ProductMoveStatus moveStatus;

  const SpaceOverviewState({
    required this.status,
    this.selectedProductIds = const {},
    this.deletionStatus = const ProductDeletionIdle(),
    this.moveStatus = const ProductMoveIdle(),
  });

  factory SpaceOverviewState.initial() {
    return const SpaceOverviewState(status: SpaceOverviewInitial());
  }

  bool get isSelecting => selectedProductIds.isNotEmpty;

  /// A deletion or a move is running; selection and other actions wait.
  bool get isBusy =>
      deletionStatus is ProductDeletionInProgress ||
      moveStatus is ProductMoveInProgress;

  SpaceOverviewState copyWith({
    SpaceOverviewStatus? status,
    Set<String>? selectedProductIds,
    ProductDeletionStatus? deletionStatus,
    ProductMoveStatus? moveStatus,
  }) {
    return SpaceOverviewState(
      status: status ?? this.status,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      moveStatus: moveStatus ?? this.moveStatus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedProductIds,
    deletionStatus,
    moveStatus,
  ];
}
