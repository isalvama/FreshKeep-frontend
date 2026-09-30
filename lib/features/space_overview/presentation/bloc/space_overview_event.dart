part of 'space_overview_bloc.dart';

sealed class SpaceOverviewEvent {
  const SpaceOverviewEvent();
}

final class SpaceOverviewRequested extends SpaceOverviewEvent {
  final String spaceId;

  const SpaceOverviewRequested(this.spaceId);
}

/// Adds [productId] to the selection if absent, removes it if present.
final class ProductSelectionToggled extends SpaceOverviewEvent {
  final String productId;

  const ProductSelectionToggled(this.productId);
}

final class ProductSelectionCleared extends SpaceOverviewEvent {
  const ProductSelectionCleared();
}

final class SelectedProductsDeleteSubmitted extends SpaceOverviewEvent {
  const SelectedProductsDeleteSubmitted();
}

/// A product was edited and saved; merge it into the loaded overview.
final class ProductUpdated extends SpaceOverviewEvent {
  final UpdatedProduct product;

  const ProductUpdated(this.product);
}

/// Moves the single selected product to [destination]'s storage spot.
final class SelectedProductMoveSubmitted extends SpaceOverviewEvent {
  final MoveDestination destination;

  const SelectedProductMoveSubmitted(this.destination);
}
