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

  /// Shows only products whose name contains it, ignoring case. Empty shows
  /// all.
  final String searchQuery;

  /// Shows only products in this storage spot. Null shows all.
  final String? storageSpotFilter;

  const SpaceOverviewState({
    required this.status,
    this.selectedProductIds = const {},
    this.deletionStatus = const ProductDeletionIdle(),
    this.moveStatus = const ProductMoveIdle(),
    this.searchQuery = '',
    this.storageSpotFilter,
  });

  factory SpaceOverviewState.initial() {
    return const SpaceOverviewState(status: SpaceOverviewInitial());
  }

  bool get isSelecting => selectedProductIds.isNotEmpty;

  /// A deletion or a move is running; selection and other actions wait.
  bool get isBusy =>
      deletionStatus is ProductDeletionInProgress ||
      moveStatus is ProductMoveInProgress;

  bool get isFiltering =>
      searchQuery.trim().isNotEmpty || storageSpotFilter != null;

  /// The loaded products that pass the search and the storage spot filter,
  /// in the overview's order. Empty until the overview loads.
  List<PersistedProduct> get visibleProducts {
    final status = this.status;
    if (status is! SpaceOverviewLoadSuccess) return const [];

    final query = searchQuery.trim().toLowerCase();
    return [
      for (final product in status.overview.productResults)
        if ((storageSpotFilter == null ||
                product.storageSpotId == storageSpotFilter) &&
            product.productName.toLowerCase().contains(query))
          product,
    ];
  }

  /// [storageSpotFilter] takes a function so it can be set back to null.
  SpaceOverviewState copyWith({
    SpaceOverviewStatus? status,
    Set<String>? selectedProductIds,
    ProductDeletionStatus? deletionStatus,
    ProductMoveStatus? moveStatus,
    String? searchQuery,
    String? Function()? storageSpotFilter,
  }) {
    return SpaceOverviewState(
      status: status ?? this.status,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      moveStatus: moveStatus ?? this.moveStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      storageSpotFilter: storageSpotFilter != null
          ? storageSpotFilter()
          : this.storageSpotFilter,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedProductIds,
    deletionStatus,
    moveStatus,
    searchQuery,
    storageSpotFilter,
  ];
}
