import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_shopping_receipt.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/product_extraction.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/confirm_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/reprocess_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/receipt_results_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';
import 'package:go_router/go_router.dart';

class _StubShoppingReceiptRepository implements ShoppingReceiptRepository {
  _StubShoppingReceiptRepository(
    this.result, {
    this.confirmResult,
    this.reprocessResult,
  });

  final Either<ShoppingReceiptFailure, ReceiptExtractionResult> result;
  final Either<ShoppingReceiptFailure, PersistedShoppingReceipt>?
  confirmResult;
  final Either<ShoppingReceiptFailure, PersistedShoppingReceipt>?
  reprocessResult;

  final Completer<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  _pendingConfirm = Completer();
  final Completer<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  _pendingReprocess = Completer();

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async => result;

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) {
    final configured = confirmResult;
    return configured != null
        ? Future.value(configured)
        : _pendingConfirm.future;
  }

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) {
    final configured = reprocessResult;
    return configured != null
        ? Future.value(configured)
        : _pendingReprocess.future;
  }
}

final _milk = ProductExtraction(
  expirationDate: DateTime(2026, 9, 15),
  productName: 'Milk',
  suggestedStorageSpotId: 'spot-1',
  productType: 'DAIRY',
  priceAmount: 2.5,
  currency: 'USD',
);

final _bread = ProductExtraction(
  expirationDate: DateTime(2026, 9, 20),
  productName: 'Bread',
  suggestedStorageSpotId: 'spot-2',
  productType: 'BAKERY',
  priceAmount: 3.0,
  currency: 'USD',
);

final _eggs = ProductExtraction(
  expirationDate: DateTime(2026, 9, 25),
  productName: 'Eggs',
  suggestedStorageSpotId: 'spot-1',
  productType: 'DAIRY',
  priceAmount: 4.0,
  currency: 'USD',
);

const _fridge = StorageSpot(
  id: 'spot-1',
  name: 'Fridge',
  type: StorageSpotType.fridge,
);

const _pantry = StorageSpot(
  id: 'spot-2',
  name: 'Pantry',
  type: StorageSpotType.pantry,
);

final _extraction = ReceiptExtractionResult(
  receiptImageId: 'receipt-1',
  suggestedStorageSpots: const [_fridge, _pantry],
  purchaseShoppingDate: DateTime(2026, 9, 8),
  storeName: 'SuperMart',
  productExtractions: [_milk, _bread, _eggs],
  flaggedProducts: [_milk, _eggs],
);

Future<ShoppingReceiptBloc> _buildSucceededBloc({
  Either<ShoppingReceiptFailure, PersistedShoppingReceipt>? confirmResult,
  Either<ShoppingReceiptFailure, PersistedShoppingReceipt>? reprocessResult,
}) async {
  final repository = _StubShoppingReceiptRepository(
    Right(_extraction),
    confirmResult: confirmResult,
    reprocessResult: reprocessResult,
  );
  final bloc = ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      repository,
    ),
    confirmShoppingReceiptUseCase: ConfirmShoppingReceiptUseCase(repository),
    reprocessShoppingReceiptUseCase: ReprocessShoppingReceiptUseCase(
      repository,
    ),
  );
  bloc.add(const SpaceForReceiptSelected('space-1'));
  bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
  bloc.add(const ReceiptProcessingSubmitted());
  await bloc.stream.firstWhere(
    (state) => state.status is ShoppingReceiptProcessSuccess,
  );
  return bloc;
}

Future<void> _pumpResultsPage(WidgetTester tester, ShoppingReceiptBloc bloc) {
  final router = GoRouter(
    initialLocation: '/process-receipt/results',
    routes: [
      GoRoute(
        path: '/process-receipt/results',
        builder: (context, state) => const ReceiptResultsPage(),
      ),
      GoRoute(
        path: '/process-receipt/reprocessed-results',
        builder: (context, state) => const Text('REPROCESSED_MARKER'),
      ),
      GoRoute(
        path: '/process-receipt/error',
        builder: (context, state) => const Text('ERROR_MARKER'),
      ),
      GoRoute(
        path: '/space-overview/:spaceId',
        builder: (context, state) =>
            Text('OVERVIEW_MARKER_${state.pathParameters['spaceId']}'),
      ),
    ],
  );

  return tester.pumpWidget(
    BlocProvider<ShoppingReceiptBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

Finder _flaggedGroupFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color ==
            Colors.red.withValues(alpha: 0.08),
  );
}

void main() {
  testWidgets('shows storeName and purchaseShoppingDate', (tester) async {
    final bloc = await _buildSucceededBloc();

    await _pumpResultsPage(tester, bloc);

    expect(find.text('SuperMart'), findsOneWidget);
    expect(find.text('2026-09-08'), findsOneWidget);
  });

  testWidgets('shows the suggested storage spot for each product', (
    tester,
  ) async {
    final bloc = await _buildSucceededBloc();

    await _pumpResultsPage(tester, bloc);

    expect(find.textContaining('Fridge'), findsNWidgets(2)); // Milk, Eggs
    expect(find.textContaining('Pantry'), findsOneWidget); // Bread
  });

  testWidgets(
    'flagged products render in a group above the rest',
    (tester) async {
      final bloc = await _buildSucceededBloc();

      await _pumpResultsPage(tester, bloc);

      final flaggedGroup = _flaggedGroupFinder();
      expect(flaggedGroup, findsOneWidget);
      expect(
        find.descendant(of: flaggedGroup, matching: find.text('Milk')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: flaggedGroup, matching: find.text('Eggs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: flaggedGroup, matching: find.text('Bread')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'every product has an unchecked checkbox that toggles reprocess selection',
    (tester) async {
      final bloc = await _buildSucceededBloc();

      await _pumpResultsPage(tester, bloc);

      final milkTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Milk'),
      );
      expect(milkTile.value, isFalse);

      await tester.tap(find.text('Milk'));
      await tester.pump();

      expect(bloc.state.selectedForReprocess, {0});
    },
  );

  testWidgets(
    'OK is enabled, and Reprocess selected products is disabled until a '
    'product is checked',
    (tester) async {
      final bloc = await _buildSucceededBloc();

      await _pumpResultsPage(tester, bloc);

      ElevatedButton reprocessButton() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Reprocess selected products'),
      );
      final okButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'OK'),
      );
      expect(okButton.onPressed, isNotNull);
      expect(reprocessButton().onPressed, isNull);

      await tester.tap(find.text('Milk'));
      await tester.pump();

      expect(reprocessButton().onPressed, isNotNull);
    },
  );

  testWidgets(
    'tapping OK dispatches a confirm action and navigates to the space overview',
    (tester) async {
      final persisted = PersistedShoppingReceipt(
        id: 'shopping-receipt-1',
        shoppingDate: DateTime(2026, 9, 8),
        storeName: 'SuperMart',
        products: const [],
        storageSpots: const [],
      );
      final bloc = await _buildSucceededBloc(confirmResult: Right(persisted));

      await _pumpResultsPage(tester, bloc);

      await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
      await tester.pumpAndSettle();

      expect(bloc.state.status, isA<ShoppingReceiptConfirmSuccess>());
      expect(find.text('OVERVIEW_MARKER_space-1'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Reprocess selected products dispatches a reprocess action and '
    'navigates to the reprocessed-results screen',
    (tester) async {
      final persisted = PersistedShoppingReceipt(
        id: 'shopping-receipt-1',
        shoppingDate: DateTime(2026, 9, 8),
        storeName: 'SuperMart',
        products: const [],
        storageSpots: const [],
      );
      final bloc = await _buildSucceededBloc(
        reprocessResult: Right(persisted),
      );

      await _pumpResultsPage(tester, bloc);

      await tester.tap(find.text('Milk'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Reprocess selected products'),
      );
      await tester.pumpAndSettle();

      expect(bloc.state.reprocessedReceipt, persisted);
      expect(find.text('REPROCESSED_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'a further unrelated state change after ReprocessSuccess does not re-navigate',
    (tester) async {
      final persisted = PersistedShoppingReceipt(
        id: 'shopping-receipt-1',
        shoppingDate: DateTime(2026, 9, 8),
        storeName: 'SuperMart',
        products: const [],
        storageSpots: const [],
      );
      final bloc = await _buildSucceededBloc(
        reprocessResult: Right(persisted),
      );

      await _pumpResultsPage(tester, bloc);

      await tester.tap(find.text('Milk'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Reprocess selected products'),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPROCESSED_MARKER'), findsOneWidget);

      bloc.add(const ReprocessSelectionToggled(1));
      await tester.pumpAndSettle();

      expect(find.text('REPROCESSED_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'the first confirm failure shows an inline SnackBar and stays on Results',
    (tester) async {
      const failure = ShoppingReceiptServerFailure('Something went wrong.');
      final bloc = await _buildSucceededBloc(
        confirmResult: const Left(failure),
      );

      await _pumpResultsPage(tester, bloc);

      await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(find.byType(ReceiptResultsPage), findsOneWidget);
      expect(bloc.state.consecutiveFailureCount, 1);
    },
  );

  testWidgets(
    'a second consecutive failure navigates to the error screen',
    (tester) async {
      const failure = ShoppingReceiptServerFailure('Something went wrong.');
      final bloc = await _buildSucceededBloc(
        confirmResult: const Left(failure),
      );

      await _pumpResultsPage(tester, bloc);

      await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
      await tester.pumpAndSettle();
      expect(bloc.state.consecutiveFailureCount, 1);

      await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
      await tester.pumpAndSettle();

      expect(find.text('ERROR_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'while confirming, both buttons are disabled and a progress indicator is shown',
    (tester) async {
      final bloc = await _buildSucceededBloc();

      await _pumpResultsPage(tester, bloc);

      await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final okButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'OK'),
      );
      final reprocessButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Reprocess selected products'),
      );
      expect(okButton.onPressed, isNull);
      expect(reprocessButton.onPressed, isNull);
    },
  );
}
