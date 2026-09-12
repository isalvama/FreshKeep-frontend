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
  return tester.pumpWidget(
    BlocProvider<ShoppingReceiptBloc>.value(
      value: bloc,
      child: const MaterialApp(home: ReceiptResultsPage()),
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

  testWidgets('tapping OK dispatches a confirm action', (tester) async {
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
  });

  testWidgets(
    'tapping Reprocess selected products dispatches a reprocess action',
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
