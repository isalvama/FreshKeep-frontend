import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../products/domain/usecases/delete_product_usecase.dart';
import '../../../products/domain/usecases/delete_products_usecase.dart';
import '../../domain/entities/space_overview.dart';
import '../../domain/usecases/get_space_overview_usecase.dart';

part 'space_overview_event.dart';
part 'space_overview_state.dart';

class SpaceOverviewBloc extends Bloc<SpaceOverviewEvent, SpaceOverviewState> {
  final GetSpaceOverviewUseCase getSpaceOverviewUseCase;
  final DeleteProductUseCase deleteProductUseCase;
  final DeleteProductsUseCase deleteProductsUseCase;

  SpaceOverviewBloc({
    required this.getSpaceOverviewUseCase,
    required this.deleteProductUseCase,
    required this.deleteProductsUseCase,
  }) : super(SpaceOverviewState.initial()) {
    on<SpaceOverviewRequested>(_onRequested);
    on<ProductSelectionToggled>(_onSelectionToggled);
    on<ProductSelectionCleared>(_onSelectionCleared);
    on<SelectedProductsDeleteSubmitted>(_onDeleteSubmitted);
  }

  bool get _isDeleting => state.deletionStatus is ProductDeletionInProgress;

  Future<void> _onRequested(
    SpaceOverviewRequested event,
    Emitter<SpaceOverviewState> emit,
  ) async {
    emit(
      state.copyWith(
        status: const SpaceOverviewLoading(),
        selectedProductIds: const {},
        deletionStatus: const ProductDeletionIdle(),
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
    if (_isDeleting) return;

    final selected = {...state.selectedProductIds};
    if (!selected.remove(event.productId)) selected.add(event.productId);
    emit(state.copyWith(selectedProductIds: Set.unmodifiable(selected)));
  }

  void _onSelectionCleared(
    ProductSelectionCleared event,
    Emitter<SpaceOverviewState> emit,
  ) {
    if (_isDeleting) return;

    emit(state.copyWith(selectedProductIds: const {}));
  }

  /// One selected product uses the single endpoint; two or more, the batch
  /// one. The batch is all-or-nothing, so success means exactly the
  /// selected products are gone and they can be pruned without a refetch.
  Future<void> _onDeleteSubmitted(
    SelectedProductsDeleteSubmitted event,
    Emitter<SpaceOverviewState> emit,
  ) async {
    if (_isDeleting || !state.isSelecting) return;

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
