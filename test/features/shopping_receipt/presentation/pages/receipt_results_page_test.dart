import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/product_extraction.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/receipt_results_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';

class _StubShoppingReceiptRepository implements ShoppingReceiptRepository {
  _StubShoppingReceiptRepository(this.result);

  final Either<ShoppingReceiptFailure, ReceiptExtractionResult> result;

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async => result;
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

Future<ShoppingReceiptBloc> _buildSucceededBloc() async {
  final bloc = ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      _StubShoppingReceiptRepository(Right(_extraction)),
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

  testWidgets('OK and Reprocess selected products are disabled', (
    tester,
  ) async {
    final bloc = await _buildSucceededBloc();

    await _pumpResultsPage(tester, bloc);

    final okButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'OK'),
    );
    final reprocessButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Reprocess selected products'),
    );
    expect(okButton.onPressed, isNull);
    expect(reprocessButton.onPressed, isNull);
  });
}
