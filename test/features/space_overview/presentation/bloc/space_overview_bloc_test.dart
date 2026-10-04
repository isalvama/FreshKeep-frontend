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
import 'package:fresh_keep_frontend/features/products/domain/usecases/move_product_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_product.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/entities/move_destination.dart';
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

  /// Answers moves with [moveResult], or waits on [movePending] when set.
  Either<ProductFailure, MovedProduct>? moveResult;
  Completer<Either<ProductFailure, MovedProduct>>? movePending;
  final List<(String, String, String)> moveCalls = [];

  @override
  Future<Either<ProductFailure, MovedProduct>> moveProduct({
    required String productId,
    required String oldStorageSpotId,
    required String newStorageSpotId,
  }) async {
    moveCalls.add((productId, oldStorageSpotId, newStorageSpotId));
    return movePending != null ? movePending!.future : moveResult!;
  }
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
    moveProductUseCase: MoveProductUseCase(products),
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

    UpdatedProduct update(
      String id,
      DateTime date, {
      String name = 'Oat milk',
    }) => UpdatedProduct(
      productId: id,
      name: name,
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

    test('orders equal dates by name, like the backend', () async {
      final bloc = await loaded();

      // p3 moves onto p2's date as "Oat milk", which sorts before "Product p2".
      bloc.add(ProductUpdated(update('p3', DateTime(2026, 10, 2))));
      await _settle();

      expect(_productIds(bloc.state), ['p1', 'p3', 'p2']);

      await bloc.close();
    });

    test('keeps the existing order for equal dates and names', () async {
      final bloc = await loaded();

      bloc.add(
        ProductUpdated(update('p3', DateTime(2026, 10, 2), name: 'Product p2')),
      );
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
        moveProductUseCase: MoveProductUseCase(productRepository),
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

  group('SelectedProductMoveSubmitted', () {
    PersistedProduct product(String id, String? spotId, DateTime date) =>
        PersistedProduct(
          id: id,
          productName: 'Product $id',
          expirationDate: date,
          storageSpotId: spotId,
          productType: 'OTHER',
          priceAmount: null,
          currency: null,
        );

    // m1 and m2 in spot-a, m3 in spot-b, m4 without a spot.
    final overview = SpaceOverview(
      id: 'space-1',
      name: 'Kitchen',
      emoji: '🏠',
      storageSpots: const [],
      productResults: [
        product('m1', 'spot-a', DateTime(2026, 10, 1)),
        product('m2', 'spot-a', DateTime(2026, 10, 5)),
        product('m3', 'spot-b', DateTime(2026, 10, 10)),
        product('m4', null, DateTime(2026, 10, 20)),
      ],
    );

    const toSpotB = MoveDestination(
      spaceId: 'space-1',
      spaceName: 'Kitchen',
      storageSpotId: 'spot-b',
      storageSpotName: 'Fridge',
    );
    const toOtherSpace = MoveDestination(
      spaceId: 'space-2',
      spaceName: 'Garage',
      storageSpotId: 'spot-x',
      storageSpotName: 'Freezer',
    );

    MovedProduct moved(String id, String spotId, DateTime date) => MovedProduct(
      productId: id,
      newStorageSpotId: spotId,
      newExpirationDate: date,
    );

    Future<SpaceOverviewBloc> loaded(
      _RecordingProductRepository products, {
      List<String> select = const ['m1'],
    }) async {
      final bloc = _buildBloc(Right(overview), productRepository: products);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await bloc.stream.firstWhere((s) => s.status is SpaceOverviewLoadSuccess);
      for (final id in select) {
        bloc.add(ProductSelectionToggled(id));
      }
      await _settle();
      return bloc;
    }

    List<PersistedProduct> productsOf(SpaceOverviewState state) =>
        (state.status as SpaceOverviewLoadSuccess).overview.productResults;

    test('within the same space, calls the use case with the current spot, '
        'updates spot and date, re-sorts and leaves selection mode', () async {
      final products = _RecordingProductRepository()
        ..moveResult = Right(moved('m1', 'spot-b', DateTime(2026, 10, 10)));
      final bloc = await loaded(products);
      final emitted = <SpaceOverviewState>[];
      final subscription = bloc.stream.listen(emitted.add);

      bloc.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();

      expect(products.moveCalls, [('m1', 'spot-a', 'spot-b')]);
      expect(emitted.first.moveStatus, isA<ProductMoveInProgress>());
      expect(emitted.first.isBusy, isTrue);

      final result = bloc.state;
      // m1 now shares m3's date and keeps its earlier position.
      expect(productsOf(result).map((p) => p.id), ['m2', 'm1', 'm3', 'm4']);
      final m1 = productsOf(result).firstWhere((p) => p.id == 'm1');
      expect(m1.storageSpotId, 'spot-b');
      expect(m1.expirationDate, DateTime(2026, 10, 10));
      expect(m1.productName, 'Product m1');
      expect(result.selectedProductIds, isEmpty);
      final status = result.moveStatus as ProductMoveSuccess;
      expect(status.destination, toSpotB);
      expect(status.newExpirationDate, DateTime(2026, 10, 10));
      expect(result.isBusy, isFalse);

      await subscription.cancel();
      await bloc.close();
    });

    test('to another space, removes the product and leaves selection '
        'mode', () async {
      final products = _RecordingProductRepository()
        ..moveResult = Right(moved('m2', 'spot-x', DateTime(2026, 9, 18)));
      final bloc = await loaded(products, select: ['m2']);

      bloc.add(const SelectedProductMoveSubmitted(toOtherSpace));
      await _settle();

      expect(products.moveCalls, [('m2', 'spot-a', 'spot-x')]);
      expect(productsOf(bloc.state).map((p) => p.id), ['m1', 'm3', 'm4']);
      expect(bloc.state.selectedProductIds, isEmpty);
      final status = bloc.state.moveStatus as ProductMoveSuccess;
      expect(status.destination, toOtherSpace);
      expect(status.newExpirationDate, DateTime(2026, 9, 18));

      await bloc.close();
    });

    test('on failure keeps the list and the selection and emits '
        'ProductMoveFailure; submitting again retries', () async {
      final products = _RecordingProductRepository()
        ..moveResult = const Left(ProductServerFailure('Server down.'));
      final bloc = await loaded(products);

      bloc.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();

      expect(productsOf(bloc.state), overview.productResults);
      expect(bloc.state.selectedProductIds, {'m1'});
      expect(
        (bloc.state.moveStatus as ProductMoveFailure).message,
        'Server down.',
      );

      products.moveResult = Right(moved('m1', 'spot-b', DateTime(2026, 10, 2)));
      bloc.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();

      expect(products.moveCalls, hasLength(2));
      expect(bloc.state.moveStatus, isA<ProductMoveSuccess>());

      await bloc.close();
    });

    test('is ignored unless exactly one product is selected', () async {
      final products = _RecordingProductRepository()
        ..moveResult = Right(moved('m1', 'spot-b', DateTime(2026, 10, 1)));
      final none = await loaded(products, select: []);
      none.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(none.state.moveStatus, isA<ProductMoveIdle>());
      await none.close();

      final two = await loaded(products, select: ['m1', 'm2']);
      two.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(two.state.moveStatus, isA<ProductMoveIdle>());
      await two.close();

      expect(products.moveCalls, isEmpty);
    });

    test('is ignored for a product without a storage spot and for its '
        'current spot', () async {
      final products = _RecordingProductRepository()
        ..moveResult = Right(moved('m1', 'spot-b', DateTime(2026, 10, 1)));
      final noSpot = await loaded(products, select: ['m4']);
      noSpot.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(noSpot.state.moveStatus, isA<ProductMoveIdle>());
      await noSpot.close();

      final sameSpot = await loaded(products, select: ['m3']);
      sameSpot.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(sameSpot.state.moveStatus, isA<ProductMoveIdle>());
      expect(sameSpot.state.selectedProductIds, {'m3'});
      await sameSpot.close();

      expect(products.moveCalls, isEmpty);
    });

    test('is ignored while loading and after a load failure', () async {
      final pending = _PendingSpaceOverviewRepository();
      final productRepository = _RecordingProductRepository();
      final loading = SpaceOverviewBloc(
        getSpaceOverviewUseCase: GetSpaceOverviewUseCase(pending),
        deleteProductUseCase: DeleteProductUseCase(productRepository),
        deleteProductsUseCase: DeleteProductsUseCase(productRepository),
        moveProductUseCase: MoveProductUseCase(productRepository),
      );
      loading.add(const SpaceOverviewRequested('space-1'));
      await _settle();
      loading.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(loading.state.moveStatus, isA<ProductMoveIdle>());
      await loading.close();

      final failed = _buildBloc(
        const Left(SpaceOverviewConflictFailure('Not a participant.')),
        productRepository: productRepository,
      );
      failed.add(const SpaceOverviewRequested('space-1'));
      await failed.stream.firstWhere(
        (s) => s.status is SpaceOverviewLoadFailure,
      );
      failed.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(failed.state.moveStatus, isA<ProductMoveIdle>());
      await failed.close();

      expect(productRepository.moveCalls, isEmpty);
    });

    test('a second submit, toggle, clear and delete are ignored while '
        'moving', () async {
      final products = _RecordingProductRepository()..movePending = Completer();
      final bloc = await loaded(products);

      bloc.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(bloc.state.moveStatus, isA<ProductMoveInProgress>());

      bloc
        ..add(const SelectedProductMoveSubmitted(toOtherSpace))
        ..add(const ProductSelectionToggled('m2'))
        ..add(const ProductSelectionCleared())
        ..add(const SelectedProductsDeleteSubmitted());
      await _settle();

      expect(products.moveCalls, hasLength(1));
      expect(products.singleCalls, isEmpty);
      expect(products.batchCalls, isEmpty);
      expect(bloc.state.selectedProductIds, {'m1'});

      products.movePending!.complete(
        Right(moved('m1', 'spot-b', DateTime(2026, 10, 1))),
      );
      await _settle();
      expect(bloc.state.moveStatus, isA<ProductMoveSuccess>());

      await bloc.close();
    });

    test('is ignored while a deletion is in progress', () async {
      final products = _RecordingProductRepository()..pending = Completer();
      final bloc = await loaded(products);

      bloc.add(const SelectedProductsDeleteSubmitted());
      await _settle();
      expect(bloc.state.isBusy, isTrue);

      bloc.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();

      expect(products.moveCalls, isEmpty);
      expect(bloc.state.moveStatus, isA<ProductMoveIdle>());

      products.pending!.complete(const Right(unit));
      await _settle();
      await bloc.close();
    });

    test('SpaceOverviewRequested resets the move status to idle', () async {
      final products = _RecordingProductRepository()
        ..moveResult = const Left(ProductServerFailure('Server down.'));
      final bloc = await loaded(products);

      bloc.add(const SelectedProductMoveSubmitted(toSpotB));
      await _settle();
      expect(bloc.state.moveStatus, isA<ProductMoveFailure>());

      bloc.add(const SpaceOverviewRequested('space-1'));
      await _settle();
      expect(bloc.state.moveStatus, isA<ProductMoveIdle>());

      await bloc.close();
    });
  });
}
