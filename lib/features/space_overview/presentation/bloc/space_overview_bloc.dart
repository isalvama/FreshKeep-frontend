import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../products/domain/entities/moved_product.dart';
import '../../../products/domain/entities/updated_product.dart';
import '../../../products/domain/usecases/delete_product_usecase.dart';
import '../../../products/domain/usecases/delete_products_usecase.dart';
import '../../../products/domain/usecases/move_product_usecase.dart';
import '../../../shopping_receipt/domain/entities/persisted_product.dart';
import '../../domain/entities/move_destination.dart';
import '../../domain/entities/space_overview.dart';
import '../../domain/usecases/get_space_overview_usecase.dart';

part 'space_overview_event.dart';
part 'space_overview_state.dart';

class SpaceOverviewBloc extends Bloc<SpaceOverviewEvent, SpaceOverviewState> {
  final GetSpaceOverviewUseCase getSpaceOverviewUseCase;
  final DeleteProductUseCase deleteProductUseCase;
  final DeleteProductsUseCase deleteProductsUseCase;
  final MoveProductUseCase moveProductUseCase;

  SpaceOverviewBloc({
    required this.getSpaceOverviewUseCase,
    required this.deleteProductUseCase,
    required this.deleteProductsUseCase,
    required this.moveProductUseCase,
  }) : super(SpaceOverviewState.initial()) {
    on<SpaceOverviewRequested>(_onRequested);
    on<ProductSelectionToggled>(_onSelectionToggled);
    on<ProductSelectionCleared>(_onSelectionCleared);
    on<SelectedProductsDeleteSubmitted>(_onDeleteSubmitted);
    on<ProductUpdated>(_onProductUpdated);
    on<SelectedProductMoveSubmitted>(_onMoveSubmitted);
  }

  Future<void> _onRequested(
    SpaceOverviewRequested event,
    Emitter<SpaceOverviewState> emit,
  ) async {
    emit(
      state.copyWith(
        status: const SpaceOverviewLoading(),
        selectedProductIds: const {},
        deletionStatus: const ProductDeletionIdle(),
        moveStatus: const ProductMoveIdle(),
      ),
    );

    final result = await getSpaceOverviewUseCase(spaceId: event.spaceId);

    result.match(
      (failure) => emit(
        state.copyWith(status: SpaceOverviewLoadFailure(failure.message)),
      ),
      (overview) =>
          emit(state.copyWith(status: SpaceOverviewLoadSuccess(overview))),
    );
  }

  void _onSelectionToggled(
    ProductSelectionToggled event,
    Emitter<SpaceOverviewState> emit,
  ) {
    if (state.isBusy) return;

    final selected = {...state.selectedProductIds};
    if (!selected.remove(event.productId)) selected.add(event.productId);
    emit(state.copyWith(selectedProductIds: Set.unmodifiable(selected)));
  }

  void _onSelectionCleared(
    ProductSelectionCleared event,
    Emitter<SpaceOverviewState> emit,
  ) {
    if (state.isBusy) return;

    emit(state.copyWith(selectedProductIds: const {}));
  }

  /// One selected product uses the single endpoint; two or more, the batch
  /// one. The batch is all-or-nothing, so success means exactly the
  /// selected products are gone and they can be pruned without a refetch.
  Future<void> _onDeleteSubmitted(
    SelectedProductsDeleteSubmitted event,
    Emitter<SpaceOverviewState> emit,
  ) async {
    if (state.isBusy || !state.isSelecting) return;

    final ids = state.selectedProductIds.toList();
    emit(state.copyWith(deletionStatus: const ProductDeletionInProgress()));

    final result = ids.length == 1
        ? await deleteProductUseCase(productId: ids.single)
        : await deleteProductsUseCase(productIds: ids);

    if (isClosed) return;

    result.match(
      (failure) => emit(
        state.copyWith(deletionStatus: ProductDeletionFailure(failure.message)),
      ),
      (_) {
        final status = state.status;
        emit(
          state.copyWith(
            status: status is SpaceOverviewLoadSuccess
                ? SpaceOverviewLoadSuccess(
                    _withoutProducts(status.overview, ids),
                  )
                : status,
            selectedProductIds: const {},
            deletionStatus: ProductDeletionSuccess(ids.length),
          ),
        );
      },
    );
  }

  /// The PATCH response has no `storageSpotId`, so the one already in the
  /// list is kept. The list stays sorted soonest-to-expire first, like the
  /// backend returns it.
  void _onProductUpdated(
    ProductUpdated event,
    Emitter<SpaceOverviewState> emit,
  ) {
    final status = state.status;
    if (status is! SpaceOverviewLoadSuccess) return;

    final products = status.overview.productResults;
    final updated = event.product;
    final index = products.indexWhere((p) => p.id == updated.productId);
    if (index == -1) return;

    final merged = [...products];
    merged[index] = PersistedProduct(
      id: updated.productId,
      productName: updated.name,
      expirationDate: updated.expirationDate,
      storageSpotId: products[index].storageSpotId,
      productType: updated.productType,
      priceAmount: updated.amount,
      currency: updated.currency,
    );

    final overview = status.overview;
    emit(
      state.copyWith(
        status: SpaceOverviewLoadSuccess(
          SpaceOverview(
            id: overview.id,
            name: overview.name,
            emoji: overview.emoji,
            storageSpots: overview.storageSpots,
            productResults: _sortedByExpiration(merged),
          ),
        ),
      ),
    );
  }

  /// Moves exactly one selected product that has a storage spot. On success
  /// the list is updated locally: within this space the product takes the
  /// new spot and date and the list is re-sorted; to another space it is
  /// removed.
  Future<void> _onMoveSubmitted(
    SelectedProductMoveSubmitted event,
    Emitter<SpaceOverviewState> emit,
  ) async {
    final status = state.status;
    if (status is! SpaceOverviewLoadSuccess || state.isBusy) return;
    if (state.selectedProductIds.length != 1) return;

    final productId = state.selectedProductIds.single;
    final product = status.overview.productResults
        .where((p) => p.id == productId)
        .firstOrNull;
    final oldStorageSpotId = product?.storageSpotId;
    final destination = event.destination;
    if (oldStorageSpotId == null ||
        oldStorageSpotId == destination.storageSpotId) {
      return;
    }

    emit(state.copyWith(moveStatus: const ProductMoveInProgress()));

    final result = await moveProductUseCase(
      productId: productId,
      oldStorageSpotId: oldStorageSpotId,
      newStorageSpotId: destination.storageSpotId,
    );

    if (isClosed) return;

    result.match(
      (failure) =>
          emit(state.copyWith(moveStatus: ProductMoveFailure(failure.message))),
      (moved) {
        final current = state.status;
        emit(
          state.copyWith(
            status: current is SpaceOverviewLoadSuccess
                ? SpaceOverviewLoadSuccess(
                    destination.spaceId == current.overview.id
                        ? _withMovedProduct(current.overview, moved)
                        : _withoutProducts(current.overview, [productId]),
                  )
                : current,
            selectedProductIds: const {},
            moveStatus: ProductMoveSuccess(
              destination: destination,
              newExpirationDate: moved.newExpirationDate,
            ),
          ),
        );
      },
    );
  }

  SpaceOverview _withMovedProduct(SpaceOverview overview, MovedProduct moved) {
    final products = [
      for (final product in overview.productResults)
        product.id == moved.productId
            ? PersistedProduct(
                id: product.id,
                productName: product.productName,
                expirationDate: moved.newExpirationDate,
                storageSpotId: moved.newStorageSpotId,
                productType: product.productType,
                priceAmount: product.priceAmount,
                currency: product.currency,
              )
            : product,
    ];
    return SpaceOverview(
      id: overview.id,
      name: overview.name,
      emoji: overview.emoji,
      storageSpots: overview.storageSpots,
      productResults: _sortedByExpiration(products),
    );
  }

  /// Stable: products with the same date keep their current order.
  List<PersistedProduct> _sortedByExpiration(List<PersistedProduct> products) {
    final indexed = products.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.expirationDate.compareTo(b.$2.expirationDate);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    return [for (final (_, product) in indexed) product];
  }

  SpaceOverview _withoutProducts(SpaceOverview overview, List<String> ids) {
    final deleted = ids.toSet();
    return SpaceOverview(
      id: overview.id,
      name: overview.name,
      emoji: overview.emoji,
      storageSpots: overview.storageSpots,
      productResults: [
        for (final product in overview.productResults)
          if (!deleted.contains(product.id)) product,
      ],
    );
  }
}
