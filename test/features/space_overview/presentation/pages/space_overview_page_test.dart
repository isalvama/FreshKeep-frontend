import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/moved_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_changes.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/update_product_usecase.dart';
import 'package:fresh_keep_frontend/features/products/presentation/bloc/edit_product_bloc.dart';
import 'package:fresh_keep_frontend/features/products/presentation/pages/edit_product_page.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/updated_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/repositories/product_repository.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/delete_product_usecase.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/delete_products_usecase.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/move_product_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_product.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/entities/space_overview.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/repositories/space_overview_repository.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/usecases/get_space_overview_usecase.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/bloc/space_overview_bloc.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/pages/space_overview_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';

class _StubSpaceOverviewRepository implements SpaceOverviewRepository {
  _StubSpaceOverviewRepository(this.results);

  final List<Either<SpaceOverviewFailure, SpaceOverview>> results;
  int _callCount = 0;

  @override
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({
    required String spaceId,
  }) async {
    final result = results[_callCount];
    if (_callCount < results.length - 1) _callCount++;
    return result;
  }
}

class _PendingSpaceOverviewRepository implements SpaceOverviewRepository {
  final Completer<Either<SpaceOverviewFailure, SpaceOverview>> completer =
      Completer();

  @override
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({
    required String spaceId,
  }) => completer.future;
}

class _UnusedProductRepository implements ProductRepository {
  @override
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  }) => throw UnimplementedError();

  @override
  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  }) => throw UnimplementedError();

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

/// Answers every update with [result] and records the calls.
class _UpdatingProductRepository implements ProductRepository {
  _UpdatingProductRepository(this.result);

  final UpdatedProduct result;
  final List<(String, ProductChanges)> updateCalls = [];

  @override
  Future<Either<ProductFailure, UpdatedProduct>> updateProduct({
    required String productId,
    required ProductChanges changes,
  }) async {
    updateCalls.add((productId, changes));
    return Right(result);
  }

  @override
  Future<Either<ProductFailure, Unit>> deleteProduct({
    required String productId,
  }) => throw UnimplementedError();

  @override
  Future<Either<ProductFailure, Unit>> deleteProducts({
    required List<String> productIds,
  }) => throw UnimplementedError();

  @override
  Future<Either<ProductFailure, MovedProduct>> moveProduct({
    required String productId,
    required String oldStorageSpotId,
    required String newStorageSpotId,
  }) => throw UnimplementedError();
}

const _fridge = StorageSpot(
  id: 'spot-1',
  name: 'Fridge',
  type: StorageSpotType.fridge,
);

final _overview = SpaceOverview(
  id: 'space-1',
  name: 'Kitchen',
  emoji: '🏠',
  storageSpots: const [_fridge],
  productResults: [
    PersistedProduct(
      id: 'product-1',
      productName: 'Milk',
      expirationDate: DateTime(2026, 9, 15),
      storageSpotId: 'spot-1',
      productType: 'DAIRY',
      priceAmount: 2.5,
      currency: 'USD',
    ),
    PersistedProduct(
      id: 'product-2',
      productName: 'Bread',
      expirationDate: DateTime(2026, 9, 20),
      storageSpotId: null,
      productType: 'BAKERY',
      priceAmount: null,
      currency: null,
    ),
  ],
);

/// The space as Home last saw it; its name differs from [_overview]'s, as if
/// it had been renamed since Home loaded its list.
const _homeSpace = Space(
  id: 'space-1',
  spaceName: 'Old kitchen',
  emoji: '🍳',
  storageSpots: [],
  creatorId: 'user-1',
  participantIds: ['user-1'],
);

const _emptyOverview = SpaceOverview(
  id: 'space-1',
  name: 'Garage',
  emoji: '🚗',
  storageSpots: [],
  productResults: [],
);

SpaceOverviewBloc _buildBloc(
  SpaceOverviewRepository repository, {
  ProductRepository? productRepository,
}) {
  final products = productRepository ?? _UnusedProductRepository();
  return SpaceOverviewBloc(
    getSpaceOverviewUseCase: GetSpaceOverviewUseCase(repository),
    deleteProductUseCase: DeleteProductUseCase(products),
    deleteProductsUseCase: DeleteProductsUseCase(products),
    moveProductUseCase: MoveProductUseCase(products),
  );
}

Future<void> _pumpOverviewPage(
  WidgetTester tester,
  SpaceOverviewBloc bloc, {
  Space? space,
}) {
  return tester.pumpWidget(
    BlocProvider<SpaceOverviewBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: SpaceOverviewPage(spaceId: 'space-1', space: space),
      ),
    ),
  );
}

/// Mirrors the app's `/home` and `/space-overview/:spaceId` routes, with
/// the overview reading its `Space` from `extra`.
GoRouter _buildRouter(SpaceOverviewBloc bloc, {required String initial}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home page'))),
      ),
      GoRoute(
        path: '/space-overview/:spaceId',
        builder: (context, state) => BlocProvider<SpaceOverviewBloc>.value(
          value: bloc,
          child: SpaceOverviewPage(
            spaceId: state.pathParameters['spaceId']!,
            space: state.extra as Space?,
          ),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('shows a loading indicator while fetching', (tester) async {
    final bloc = _buildBloc(_PendingSpaceOverviewRepository());

    await _pumpOverviewPage(tester, bloc);
    bloc.add(const SpaceOverviewRequested('space-1'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'shows the space name/emoji and every product with its resolved storage spot',
    (tester) async {
      final bloc = _buildBloc(_StubSpaceOverviewRepository([Right(_overview)]));

      await _pumpOverviewPage(tester, bloc);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();

      expect(find.text('🏠 Kitchen'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.textContaining('Fridge'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.textContaining('No suggested spot'), findsOneWidget);
    },
  );

  testWidgets('an empty productResults list shows an empty state', (
    tester,
  ) async {
    final bloc = _buildBloc(
      _StubSpaceOverviewRepository([const Right(_emptyOverview)]),
    );

    await _pumpOverviewPage(tester, bloc);
    bloc.add(const SpaceOverviewRequested('space-1'));
    await tester.pumpAndSettle();

    expect(find.text('🚗 Garage'), findsOneWidget);
    expect(find.text('No products yet.'), findsOneWidget);
  });

  testWidgets('shows the failure message and Retry re-fetches successfully', (
    tester,
  ) async {
    const failure = SpaceOverviewConflictFailure(
      'You are not a participant of this space.',
    );
    final bloc = _buildBloc(
      _StubSpaceOverviewRepository([const Left(failure), Right(_overview)]),
    );

    await _pumpOverviewPage(tester, bloc);
    bloc.add(const SpaceOverviewRequested('space-1'));
    await tester.pumpAndSettle();

    expect(
      find.text('You are not a participant of this space.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('🏠 Kitchen'), findsOneWidget);
  });

  group('AppBar title', () {
    testWidgets('while loading, uses the space passed from Home', (
      tester,
    ) async {
      final bloc = _buildBloc(_PendingSpaceOverviewRepository());

      await _pumpOverviewPage(tester, bloc, space: _homeSpace);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('🍳 Old kitchen'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('while loading without a space, falls back to "Space"', (
      tester,
    ) async {
      final bloc = _buildBloc(_PendingSpaceOverviewRepository());

      await _pumpOverviewPage(tester, bloc);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Space')),
        findsOneWidget,
      );
    });

    testWidgets('on load failure, uses the space passed from Home', (
      tester,
    ) async {
      final bloc = _buildBloc(
        _StubSpaceOverviewRepository([
          const Left(SpaceOverviewConflictFailure('Nope.')),
        ]),
      );

      await _pumpOverviewPage(tester, bloc, space: _homeSpace);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();

      expect(find.text('Nope.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('🍳 Old kitchen'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('on load failure without a space, falls back to "Space"', (
      tester,
    ) async {
      final bloc = _buildBloc(
        _StubSpaceOverviewRepository([
          const Left(SpaceOverviewConflictFailure('Nope.')),
        ]),
      );

      await _pumpOverviewPage(tester, bloc);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Space')),
        findsOneWidget,
      );
    });

    testWidgets(
      'once loaded, uses the overview response even when the passed space '
      'differs',
      (tester) async {
        final bloc = _buildBloc(
          _StubSpaceOverviewRepository([Right(_overview)]),
        );

        await _pumpOverviewPage(tester, bloc, space: _homeSpace);
        bloc.add(const SpaceOverviewRequested('space-1'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('🏠 Kitchen'),
          ),
          findsOneWidget,
        );
        expect(find.text('🍳 Old kitchen'), findsNothing);
      },
    );
  });

  group('leading button', () {
    testWidgets(
      'with nothing to pop (receipt flow), "Back to Home" goes to /home',
      (tester) async {
        final bloc = _buildBloc(
          _StubSpaceOverviewRepository([Right(_overview)]),
        );
        final router = _buildRouter(bloc, initial: '/space-overview/space-1');
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        bloc.add(const SpaceOverviewRequested('space-1'));
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsNothing);
        await tester.tap(find.byTooltip('Back to Home'));
        await tester.pumpAndSettle();

        expect(find.text('Home page'), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/home',
        );
      },
    );

    testWidgets(
      'with nothing to pop, "Back to Home" is also shown while loading and '
      'on load failure',
      (tester) async {
        final bloc = _buildBloc(
          _StubSpaceOverviewRepository([
            const Left(SpaceOverviewConflictFailure('Nope.')),
          ]),
        );
        final router = _buildRouter(bloc, initial: '/space-overview/space-1');
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byTooltip('Back to Home'), findsOneWidget);

        bloc.add(const SpaceOverviewRequested('space-1'));
        await tester.pumpAndSettle();

        expect(find.text('Nope.'), findsOneWidget);
        expect(find.byTooltip('Back to Home'), findsOneWidget);
      },
    );

    testWidgets('pushed from Home, the back arrow pops back to Home', (
      tester,
    ) async {
      final bloc = _buildBloc(_StubSpaceOverviewRepository([Right(_overview)]));
      final router = _buildRouter(bloc, initial: '/home');
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/space-overview/space-1', extra: _homeSpace);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back to Home'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Home page'), findsOneWidget);
    });
  });

  group('selection mode', () {
    Finder appBarText(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));

    Future<SpaceOverviewBloc> pumpLoaded(WidgetTester tester) async {
      final bloc = _buildBloc(_StubSpaceOverviewRepository([Right(_overview)]));
      await _pumpOverviewPage(tester, bloc);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();
      return bloc;
    }

    // Tapping a row outside selection mode opens the editor: see "editing".
    testWidgets('outside selection mode there are no checkboxes', (
      tester,
    ) async {
      await pumpLoaded(tester);

      expect(find.byType(Checkbox), findsNothing);
      expect(appBarText('🏠 Kitchen'), findsOneWidget);
      expect(find.byTooltip('Cancel selection'), findsNothing);
    });

    testWidgets('a long press enters selection mode with that row checked', (
      tester,
    ) async {
      await pumpLoaded(tester);

      await tester.longPress(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNWidgets(2));
      final milkCheckbox = tester.widget<Checkbox>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Milk'),
          matching: find.byType(Checkbox),
        ),
      );
      expect(milkCheckbox.value, isTrue);
      final breadCheckbox = tester.widget<Checkbox>(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Bread'),
          matching: find.byType(Checkbox),
        ),
      );
      expect(breadCheckbox.value, isFalse);
      expect(appBarText('1 selected'), findsOneWidget);
      expect(appBarText('🏠 Kitchen'), findsNothing);
      expect(find.byTooltip('Cancel selection'), findsOneWidget);
    });

    testWidgets('tapping rows toggles them, and deselecting the last one '
        'leaves selection mode', (tester) async {
      await pumpLoaded(tester);

      await tester.longPress(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      expect(appBarText('2 selected'), findsOneWidget);

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      expect(appBarText('1 selected'), findsOneWidget);

      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(appBarText('🏠 Kitchen'), findsOneWidget);
    });

    testWidgets('the close button clears the selection', (tester) async {
      await pumpLoaded(tester);

      await tester.longPress(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(appBarText('🏠 Kitchen'), findsOneWidget);
    });

    testWidgets('system back while selecting clears the selection and stays; '
        'back again returns to Home', (tester) async {
      final bloc = _buildBloc(_StubSpaceOverviewRepository([Right(_overview)]));
      final router = _buildRouter(bloc, initial: '/home');
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/space-overview/space-1', extra: _homeSpace);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Milk'));
      await tester.pumpAndSettle();
      expect(appBarText('1 selected'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Home page'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(appBarText('🏠 Kitchen'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Home page'), findsOneWidget);
    });
  });

  group('deleting', () {
    Finder appBarText(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));

    Future<SpaceOverviewBloc> pumpLoaded(
      WidgetTester tester,
      _RecordingProductRepository products,
    ) async {
      final bloc = _buildBloc(
        _StubSpaceOverviewRepository([Right(_overview)]),
        productRepository: products,
      );
      await _pumpOverviewPage(tester, bloc);
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();
      return bloc;
    }

    Future<void> select(WidgetTester tester, List<String> names) async {
      await tester.longPress(find.text(names.first));
      await tester.pumpAndSettle();
      for (final name in names.skip(1)) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
    }

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    }

    testWidgets('the delete icon only shows in selection mode', (tester) async {
      await pumpLoaded(tester, _RecordingProductRepository());
      expect(find.byTooltip('Delete selected'), findsNothing);

      await select(tester, ['Milk']);

      expect(find.byTooltip('Delete selected'), findsOneWidget);
    });

    testWidgets('the icon opens a dialog with the selected count, and Cancel '
        'deletes nothing and keeps the selection', (tester) async {
      final products = _RecordingProductRepository();
      await pumpLoaded(tester, products);
      await select(tester, ['Milk', 'Bread']);

      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 products?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(products.singleCalls, isEmpty);
      expect(products.batchCalls, isEmpty);
      expect(appBarText('2 selected'), findsOneWidget);
    });

    testWidgets('with 1 selected, the dialog says "1 product" and Delete uses '
        'the single endpoint, removes the row and shows a SnackBar', (
      tester,
    ) async {
      final products = _RecordingProductRepository();
      await pumpLoaded(tester, products);
      await select(tester, ['Milk']);

      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 1 product?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(products.singleCalls, ['product-1']);
      expect(products.batchCalls, isEmpty);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(appBarText('🏠 Kitchen'), findsOneWidget);
      expect(find.text('1 product deleted'), findsOneWidget);
    });

    testWidgets('with 2 selected, Delete uses the batch endpoint; deleting '
        'every product shows the empty state', (tester) async {
      final products = _RecordingProductRepository();
      await pumpLoaded(tester, products);
      await select(tester, ['Milk', 'Bread']);

      await confirmDelete(tester);
      await tester.pumpAndSettle();

      expect(products.singleCalls, isEmpty);
      expect(products.batchCalls, hasLength(1));
      expect(
        products.batchCalls.single,
        unorderedEquals(['product-1', 'product-2']),
      );
      expect(find.text('No products yet.'), findsOneWidget);
      expect(find.text('2 products deleted'), findsOneWidget);
    });

    testWidgets('while the request is in flight, a spinner replaces the '
        'icon and the selection is locked', (tester) async {
      final products = _RecordingProductRepository()
        ..pending = Completer<Either<ProductFailure, Unit>>();
      await pumpLoaded(tester, products);
      await select(tester, ['Milk']);

      await confirmDelete(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Delete selected'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.tap(find.text('Bread'));
      await tester.pump();
      expect(appBarText('1 selected'), findsOneWidget);

      products.pending!.complete(const Right(unit));
      await tester.pumpAndSettle();

      expect(find.text('Milk'), findsNothing);
      expect(find.text('1 product deleted'), findsOneWidget);
    });

    testWidgets('on failure, rows and selection stay, the SnackBar shows the '
        'message, and Delete can be retried', (tester) async {
      final products = _RecordingProductRepository(
        result: const Left(ProductValidationFailure('Product not found')),
      );
      await pumpLoaded(tester, products);
      await select(tester, ['Milk']);

      await confirmDelete(tester);
      await tester.pumpAndSettle();

      expect(find.text('Product not found'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(appBarText('1 selected'), findsOneWidget);

      products.result = const Right(unit);
      await confirmDelete(tester);
      await tester.pumpAndSettle();

      expect(products.singleCalls, ['product-1', 'product-1']);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('1 product deleted'), findsOneWidget);
    });
  });

  group('editing', () {
    /// Milk, renamed and moved to after Bread's Sep 20.
    final oatMilk = UpdatedProduct(
      productId: 'product-1',
      name: 'Oat milk',
      expirationDate: DateTime(2026, 9, 25),
      productType: 'DAIRY',
      amount: 2.5,
      currency: 'USD',
    );

    /// Mirrors the app's overview and edit routes.
    Future<(SpaceOverviewBloc, _UpdatingProductRepository)> pumpLoaded(
      WidgetTester tester,
    ) async {
      final products = _UpdatingProductRepository(oatMilk);
      final bloc = _buildBloc(_StubSpaceOverviewRepository([Right(_overview)]));
      final router = GoRouter(
        initialLocation: '/space-overview/space-1',
        routes: [
          GoRoute(
            path: '/space-overview/:spaceId',
            builder: (context, state) => BlocProvider<SpaceOverviewBloc>.value(
              value: bloc,
              child: SpaceOverviewPage(
                spaceId: state.pathParameters['spaceId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/space-overview/:spaceId/products/:productId/edit',
            builder: (context, state) => BlocProvider(
              create: (_) => EditProductBloc(
                updateProductUseCase: UpdateProductUseCase(products),
                product: state.extra as PersistedProduct,
              ),
              child: const EditProductPage(),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      bloc.add(const SpaceOverviewRequested('space-1'));
      await tester.pumpAndSettle();
      return (bloc, products);
    }

    List<String> rowTitles(WidgetTester tester) => [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        ((tile.title as Text).data)!,
    ];

    testWidgets('tapping a row outside selection mode opens its editor', (
      tester,
    ) async {
      await pumpLoaded(tester);

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(find.text('Edit product'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('edit_product_name')))
            .controller!
            .text,
        'Milk',
      );
    });

    testWidgets('saving returns to the overview with the row updated and '
        're-sorted, and shows "Product updated"', (tester) async {
      final (bloc, products) = await pumpLoaded(tester);
      expect(rowTitles(tester), ['Milk', 'Bread']);

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit_product_name')),
        'Oat milk',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(products.updateCalls, [
        ('product-1', const ProductChanges(name: 'Oat milk')),
      ]);
      expect(find.text('Edit product'), findsNothing);
      expect(rowTitles(tester), ['Bread', 'Oat milk']);
      expect(find.textContaining('Fridge'), findsOneWidget);
      expect(find.textContaining('exp. 2026-09-25'), findsOneWidget);
      expect(find.text('Product updated'), findsOneWidget);

      final overview = (bloc.state.status as SpaceOverviewLoadSuccess).overview;
      expect(overview.productResults.last.storageSpotId, 'spot-1');
    });

    testWidgets('closing without saving leaves the list unchanged and shows '
        'no SnackBar', (tester) async {
      final (_, products) = await pumpLoaded(tester);

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Edit product'), findsNothing);
      expect(rowTitles(tester), ['Milk', 'Bread']);
      expect(find.byType(SnackBar), findsNothing);
      expect(products.updateCalls, isEmpty);
    });

    testWidgets('in selection mode, tapping a row toggles it and does not '
        'open the editor', (tester) async {
      final (bloc, _) = await pumpLoaded(tester);

      await tester.longPress(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();

      expect(find.text('Edit product'), findsNothing);
      expect(bloc.state.selectedProductIds, {'product-1', 'product-2'});

      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(find.text('Edit product'), findsNothing);
      expect(bloc.state.selectedProductIds, {'product-2'});
    });
  });
}
