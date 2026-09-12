import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_product.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/entities/space_overview.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/repositories/space_overview_repository.dart';
import 'package:fresh_keep_frontend/features/space_overview/domain/usecases/get_space_overview_usecase.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/bloc/space_overview_bloc.dart';
import 'package:fresh_keep_frontend/features/space_overview/presentation/pages/space_overview_page.dart';
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

const _emptyOverview = SpaceOverview(
  id: 'space-1',
  name: 'Garage',
  emoji: '🚗',
  storageSpots: [],
  productResults: [],
);

SpaceOverviewBloc _buildBloc(SpaceOverviewRepository repository) {
  return SpaceOverviewBloc(
    getSpaceOverviewUseCase: GetSpaceOverviewUseCase(repository),
  );
}

Future<void> _pumpOverviewPage(WidgetTester tester, SpaceOverviewBloc bloc) {
  return tester.pumpWidget(
    BlocProvider<SpaceOverviewBloc>.value(
      value: bloc,
      child: const MaterialApp(
        home: SpaceOverviewPage(spaceId: 'space-1'),
      ),
    ),
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
      final bloc = _buildBloc(
        _StubSpaceOverviewRepository([Right(_overview)]),
      );

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

  testWidgets(
    'shows the failure message and Retry re-fetches successfully',
    (tester) async {
      const failure = SpaceOverviewConflictFailure(
        'You are not a participant of this space.',
      );
      final bloc = _buildBloc(
        _StubSpaceOverviewRepository([
          const Left(failure),
          Right(_overview),
        ]),
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
    },
  );
}
