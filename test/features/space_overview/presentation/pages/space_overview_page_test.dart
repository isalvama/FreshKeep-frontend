import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/products/domain/repositories/product_repository.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/delete_product_usecase.dart';
import 'package:fresh_keep_frontend/features/products/domain/usecases/delete_products_usecase.dart';
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
}
