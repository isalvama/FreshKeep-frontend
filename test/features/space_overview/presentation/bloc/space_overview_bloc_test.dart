import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/moved_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_changes.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/updated_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/repositories/product_repository.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/delete_product_usecase.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/delete_products_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_product.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/entities/space_overview.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/repositories/space_overview_repository.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/usecases/get_space_overview_usecase.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/bloc/space_overview_bloc.dart';

class _StubSpaceOverviewRepository implements SpaceOverviewRepository {
  _StubSpaceOverviewRepository(this.result);

  final Either<SpaceOverviewFailure, SpaceOverview> result;

  @override
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({
    required String spaceId,
  }) async => result;
}

/// Never resolves until [completer] is completed, so the bloc stays Loading.
class _PendingSpaceOverviewRepository implements SpaceOverviewRepository {
  final Completer<Either<SpaceOverviewFailure, SpaceOverview>> completer =
      Completer();

  @override
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({
    required String spaceId,
  }) => completer.future;
}

const _overview = SpaceOverview(
  id: 'space-1',
  name: 'Kitchen',
  emoji: '🏠',
  storageSpots: [],
  productResults: [],
);

/// Records every delete call. Each call resolves with [result], or waits on
/// [pending] when it is set.
class _RecordingProductRepository implements ProductRepository {
  _RecordingProductRepository({this.result = const Right(unit)});

  Either<ProductFailure, Unit> result;
  Completer<Either<ProductFailure, Unit>>? pending;
  final List<String> singleCalls = [];
  final List<List<String>> batchCalls = [];

  Future<Either<ProductFailure, Unit>> _respond() async =>
      pending != null ? pending!.future : result;

  @override
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  }) {
    singleCalls.add(productId);
    return _respond();
  }

  @override
  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  }) {
    batchCalls.add(productIds);
    return _respond();
  }

  @override
  Future<Either<ProductFailure, UpdatedProduct>> updateProduct({
    required String productId,
    required ProductChanges changes,
  }) => throw UnimplementedError();

  @override
  Future<Either<ProductFailure, MovedProduct>> moveProduct({
    required String productId,
    required String oldStorageSpotId,
    required String newStorageSpotId,
  }) => throw UnimplementedError();
}

PersistedProduct _product(String id) => PersistedProduct(
  id: id,
  productName: 'Product $id',
  expirationDate: DateTime(2026, 10, 1),
  storageSpotId: null,
  productType: 'OTHER',
  priceAmount: null,
  currency: null,
);

final _overviewWithProducts = SpaceOverview(
  id: 'space-1',
  name: 'Kitchen',
  emoji: '🏠',
  storageSpots: const [],
  productResults: [_product('p1'), _product('p2'), _product('p3')],
);

SpaceOverviewBloc _buildBloc(
  Either<SpaceOverviewFailure, SpaceOverview> result, {
  ProductRepository? productRepository,
}) {
  final products = productRepository ?? _RecordingProductRepository();
  return SpaceOverviewBloc(
    getSpaceOverviewUseCase: GetSpaceOverviewUseCase(
      _StubSpaceOverviewRepository(result),
    ),
    deleteProductUseCase: DeleteProductUseCase(products),
    deleteProductsUseCase: DeleteProductsUseCase(products),
  );
}

/// A bloc whose overview (three products) has already loaded.
Future<SpaceOverviewBloc> _loadedBloc(
  _RecordingProductRepository products,
) async {
  final bloc = _buildBloc(
    Right(_overviewWithProducts),
    productRepository: products,
  );
  bloc.add(const SpaceOverviewRequested('space-1'));
  await bloc.stream.firstWhere((s) => s.status is SpaceOverviewLoadSuccess);
  return bloc;
}

/// Lets queued events run and stubbed use cases resolve.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<String> _productIds(SpaceOverviewState state) =>
    (state.status as SpaceOverviewLoadSuccess).overview.productResults
        .map((p) => p.id)
        .toList();

void main() {
  test('initial status is SpaceOverviewInitial', () {
    final bloc = _buildBloc(const Right(_overview));

    expect(bloc.state.status, isA<SpaceOverviewInitial>());

    bloc.close();
  });

  test(
    'SpaceOverviewRequested emits Loading then LoadSuccess on success',
    () async {
      final bloc = _buildBloc(const Right(_overview));
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const SpaceOverviewRequested('space-1'));

      await bloc.stream.firstWhere(
        (state) => state.status is SpaceOverviewLoadSuccess,
      );

      expect(emittedStatuses.whereType<SpaceOverviewLoading>(), hasLength(1));
      final successStatus = emittedStatuses.last as SpaceOverviewLoadSuccess;
      expect(successStatus.overview, _overview);

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'SpaceOverviewRequested emits Loading then LoadFailure on failure',
    () async {
      const failure = SpaceOverviewConflictFailure(
        'You are not a participant of this space.',
      );
      final bloc = _buildBloc(const Left(failure));
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const SpaceOverviewRequested('space-1'));

      await bloc.stream.firstWhere(
        (state) => state.status is SpaceOverviewLoadFailure,
      );

      expect(emittedStatuses.whereType<SpaceOverviewLoading>(), hasLength(1));
      final failureStatus = emittedStatuses.last as SpaceOverviewLoadFailure;
      expect(failureStatus.message, failure.message);

      await subscription.cancel();
      await bloc.close();
    },
  );

  group('selection', () {
    test('starts empty and not selecting', () {
      final bloc = _buildBloc(const Right(_overview));

      expect(bloc.state.selectedProductIds, isEmpty);
      expect(bloc.state.isSelecting, isFalse);
      expect(bloc.state.deletionStatus, isA<ProductDeletionIdle>());

      bloc.close();
    });

    test(
      'ProductSelectionToggled adds an absent id and removes a present one',
      () async {
        final bloc = await _loadedBloc(_RecordingProductRepository());

        bloc.add(const ProductSelectionToggled('p1'));
        bloc.add(const ProductSelectionToggled('p2'));
        await _settle();
        expect(bloc.state.selectedProductIds, {'p1', 'p2'});
        expect(bloc.state.isSelecting, isTrue);

        bloc.add(const ProductSelectionToggled('p1'));
        await _settle();
        expect(bloc.state.selectedProductIds, {'p2'});

        bloc.add(const ProductSelectionToggled('p2'));
        await _settle();
        expect(bloc.state.selectedProductIds, isEmpty);
        expect(bloc.state.isSelecting, isFalse);

        await bloc.close();
      },
    );

    test('ProductSelectionCleared empties the selection', () async {
      final bloc = await _loadedBloc(_RecordingProductRepository());

      bloc.add(const ProductSelectionToggled('p1'));
      bloc.add(const ProductSelectionToggled('p2'));
      bloc.add(const ProductSelectionCleared());
      await _settle();

      expect(bloc.state.selectedProductIds, isEmpty);

      await bloc.close();
    });

    test(
      'SpaceOverviewRequested resets the selection and deletion status',
      () async {
        final products = _RecordingProductRepository(
          result: const Left(ProductNetworkFailure('offline')),
        );
        final bloc = await _loadedBloc(products);
        bloc.add(const ProductSelectionToggled('p1'));
        bloc.add(const SelectedProductsDeleteSubmitted());
        await _settle();
        expect(bloc.state.deletionStatus, isA<ProductDeletionFailure>());

        bloc.add(const SpaceOverviewRequested('space-1'));
        await _settle();

        expect(bloc.state.selectedProductIds, isEmpty);
        expect(bloc.state.deletionStatus, isA<ProductDeletionIdle>());

        await bloc.close();
      },
    );
  });

  group('SelectedProductsDeleteSubmitted', () {
    test('with 1 selected, calls only the single delete', () async {
      final products = _RecordingProductRepository();
      final bloc = await _loadedBloc(products);

      bloc.add(const ProductSelectionToggled('p2'));
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      expect(products.singleCalls, ['p2']);
      expect(products.batchCalls, isEmpty);

      await bloc.close();
    });

    test(
      'with 2 or more selected, calls only the batch delete with all ids',
      () async {
        final products = _RecordingProductRepository();
        final bloc = await _loadedBloc(products);

        bloc.add(const ProductSelectionToggled('p1'));
        bloc.add(const ProductSelectionToggled('p3'));
        bloc.add(const SelectedProductsDeleteSubmitted());
        await _settle();

        expect(products.singleCalls, isEmpty);
        expect(products.batchCalls, hasLength(1));
        expect(products.batchCalls.single, unorderedEquals(['p1', 'p3']));

        await bloc.close();
      },
    );

    test('emits InProgress, then on success removes exactly those products, '
        'clears the selection and emits Success(count)', () async {
      final products = _RecordingProductRepository();
      final bloc = await _loadedBloc(products);
      bloc.add(const ProductSelectionToggled('p1'));
      bloc.add(const ProductSelectionToggled('p3'));
      await _settle();

      final deletionStatuses = <ProductDeletionStatus>[];
      final subscription = bloc.stream.listen(
        (s) => deletionStatuses.add(s.deletionStatus),
      );

      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      expect(deletionStatuses.first, isA<ProductDeletionInProgress>());
      final success = bloc.state.deletionStatus as ProductDeletionSuccess;
      expect(success.deletedCount, 2);
      expect(_productIds(bloc.state), ['p2']);
      expect(bloc.state.selectedProductIds, isEmpty);

      await subscription.cancel();
      await bloc.close();
    });

    test('on failure keeps the list and the selection and emits '
        'Failure(message)', () async {
      final products = _RecordingProductRepository(
        result: const Left(ProductValidationFailure('Product not found')),
      );
      final bloc = await _loadedBloc(products);

      bloc.add(const ProductSelectionToggled('p1'));
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      final failure = bloc.state.deletionStatus as ProductDeletionFailure;
      expect(failure.message, 'Product not found');
      expect(_productIds(bloc.state), ['p1', 'p2', 'p3']);
      expect(bloc.state.selectedProductIds, {'p1'});

      await bloc.close();
    });

    test('after a failure, submitting again retries', () async {
      final products = _RecordingProductRepository(
        result: const Left(ProductNetworkFailure('offline')),
      );
      final bloc = await _loadedBloc(products);
      bloc.add(const ProductSelectionToggled('p1'));
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      products.result = const Right(unit);
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      expect(products.singleCalls, ['p1', 'p1']);
      expect(bloc.state.deletionStatus, isA<ProductDeletionSuccess>());
      expect(_productIds(bloc.state), ['p2', 'p3']);

      await bloc.close();
    });

    test('toggle, clear and submit are ignored while InProgress', () async {
      final products = _RecordingProductRepository()
        ..pending = Completer<Either<ProductFailure, Unit>>();
      final bloc = await _loadedBloc(products);
      bloc.add(const ProductSelectionToggled('p1'));
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();
      expect(bloc.state.deletionStatus, isA<ProductDeletionInProgress>());

      bloc.add(const ProductSelectionToggled('p2'));
      bloc.add(const ProductSelectionCleared());
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      expect(bloc.state.selectedProductIds, {'p1'});
      expect(products.singleCalls, ['p1']);
      expect(products.batchCalls, isEmpty);

      products.pending!.complete(const Right(unit));
      await _settle();
      expect(bloc.state.deletionStatus, isA<ProductDeletionSuccess>());

      await bloc.close();
    });

    test('with an empty selection does nothing', () async {
      final products = _RecordingProductRepository();
      final bloc = await _loadedBloc(products);
      final before = bloc.state;
      final emitted = <SpaceOverviewState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      expect(emitted, isEmpty);
      expect(bloc.state, before);
      expect(products.singleCalls, isEmpty);
      expect(products.batchCalls, isEmpty);

      await subscription.cancel();
      await bloc.close();
    });

    test('a success arriving after a reload prunes by id from the reloaded '
        'overview', () async {
      final products = _RecordingProductRepository()
        ..pending = Completer<Either<ProductFailure, Unit>>();
      final bloc = await _loadedBloc(products);
      bloc.add(const ProductSelectionToggled('p1'));
      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();

      // The reload resets the deletion status to Idle and loads the three
      // products again. The deleted product is gone on the backend, so it is
      // removed from whatever overview is loaded when the success arrives.
      bloc.add(const SpaceOverviewRequested('space-1'));
      await _settle();
      expect(_productIds(bloc.state), ['p1', 'p2', 'p3']);

      products.pending!.complete(const Right(unit));
      await _settle();

      expect(_productIds(bloc.state), ['p2', 'p3']);

      await bloc.close();
    });
  });

  group('ProductUpdated', () {
    PersistedProduct dated(String id, DateTime date, {String? spot}) =>
        PersistedProduct(
          id: id,
          productName: 'Product $id',
          expirationDate: date,
          storageSpotId: spot,
          productType: 'OTHER',
          priceAmount: null,
          currency: null,
        );

    /// p1 (Oct 1, Fridge), p2 (Oct 2), p3 (Oct 3).
    final datedOverview = SpaceOverview(
      id: 'space-1',
      name: 'Kitchen',
      emoji: '🏠',
      storageSpots: const [],
      productResults: [
        dated('p1', DateTime(2026, 10, 1), spot: 'spot-1'),
        dated('p2', DateTime(2026, 10, 2)),
        dated('p3', DateTime(2026, 10, 3)),
      ],
    );

    UpdatedProduct update(String id, DateTime date) => UpdatedProduct(
      productId: id,
      name: 'Oat milk',
      expirationDate: date,
      productType: 'DAIRY',
      amount: 2.5,
      currency: 'EUR',
    );

    Future<SpaceOverviewBloc> loaded() async {
      final bloc = _buildBloc(Right(datedOverview));
      bloc.add(const SpaceOverviewRequested('space-1'));
      await bloc.stream.firstWhere((s) => s.status is SpaceOverviewLoadSuccess);
      return bloc;
    }

    List<PersistedProduct> products(SpaceOverviewState state) =>
        (state.status as SpaceOverviewLoadSuccess).overview.productResults;

    test(
      'merges the update into the product and keeps its storage spot',
      () async {
        final bloc = await loaded();

        bloc.add(ProductUpdated(update('p1', DateTime(2026, 10, 1))));
        await _settle();

        expect(
          products(bloc.state).first,
          PersistedProduct(
            id: 'p1',
            productName: 'Oat milk',
            expirationDate: DateTime(2026, 10, 1),
            storageSpotId: 'spot-1',
            productType: 'DAIRY',
            priceAmount: 2.5,
            currency: 'EUR',
          ),
        );
        expect(_productIds(bloc.state), ['p1', 'p2', 'p3']);

        await bloc.close();
      },
    );

    test('re-sorts by expiration date when the date changes', () async {
      final bloc = await loaded();

      bloc.add(ProductUpdated(update('p1', DateTime(2026, 10, 5))));
      await _settle();
      expect(_productIds(bloc.state), ['p2', 'p3', 'p1']);

      bloc.add(ProductUpdated(update('p3', DateTime(2026, 9, 30))));
      await _settle();
      expect(_productIds(bloc.state), ['p3', 'p2', 'p1']);

      await bloc.close();
    });

    test('keeps the existing order for equal dates', () async {
      final bloc = await loaded();

      // p3 moves onto p2's date: p2 was first, so it stays first.
      bloc.add(ProductUpdated(update('p3', DateTime(2026, 10, 2))));
      await _settle();

      expect(_productIds(bloc.state), ['p1', 'p2', 'p3']);

      await bloc.close();
    });

    test('an unknown id emits nothing', () async {
      final bloc = await loaded();
      final emitted = <SpaceOverviewState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(ProductUpdated(update('missing', DateTime(2026, 10, 1))));
      await _settle();

      expect(emitted, isEmpty);

      await subscription.cancel();
      await bloc.close();
    });

    test('is ignored while loading and after a load failure', () async {
      final pending = _PendingSpaceOverviewRepository();
      final productRepository = _RecordingProductRepository();
      final loading = SpaceOverviewBloc(
        getSpaceOverviewUseCase: GetSpaceOverviewUseCase(pending),
        deleteProductUseCase: DeleteProductUseCase(productRepository),
        deleteProductsUseCase: DeleteProductsUseCase(productRepository),
      );
      loading.add(const SpaceOverviewRequested('space-1'));
      await _settle();
      expect(loading.state.status, isA<SpaceOverviewLoading>());
      final loadingEmitted = <SpaceOverviewState>[];
      final loadingSubscription = loading.stream.listen(loadingEmitted.add);
      loading.add(ProductUpdated(update('p1', DateTime(2026, 10, 5))));
      await _settle();
      expect(loadingEmitted, isEmpty);
      await loadingSubscription.cancel();
      await loading.close();

      final failed = _buildBloc(
        const Left(SpaceOverviewConflictFailure('Not a participant.')),
      );
      failed.add(const SpaceOverviewRequested('space-1'));
      await failed.stream.firstWhere(
        (s) => s.status is SpaceOverviewLoadFailure,
      );
      final failedEmitted = <SpaceOverviewState>[];
      final failedSubscription = failed.stream.listen(failedEmitted.add);
      failed.add(ProductUpdated(update('p1', DateTime(2026, 10, 1))));
      await _settle();
      expect(failedEmitted, isEmpty);
      await failedSubscription.cancel();
      await failed.close();
    });
  });
}
