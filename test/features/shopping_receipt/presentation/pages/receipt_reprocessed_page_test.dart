import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_product.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_shopping_receipt.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/product_extraction.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/confirm_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/reprocess_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/receipt_reprocessed_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';
import 'package:go_router/go_router.dart';

class _StubShoppingReceiptRepository implements ShoppingReceiptRepository {
  _StubShoppingReceiptRepository(this.processResult, this.reprocessResult);

  final Either<ShoppingReceiptFailure, ReceiptExtractionResult> processResult;
  final Either<ShoppingReceiptFailure, PersistedShoppingReceipt>
  reprocessResult;

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async => processResult;

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) => throw UnimplementedError();

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
  }) async => reprocessResult;
}

final _extraction = ReceiptExtractionResult(
  receiptImageId: 'receipt-1',
  suggestedStorageSpots: const [],
  purchaseShoppingDate: DateTime(2026, 9, 8),
  storeName: 'SuperMart',
  productExtractions: [
    ProductExtraction(
      expirationDate: DateTime(2026, 9, 15),
      productName: 'Milk',
      suggestedStorageSpotId: 'spot-1',
      productType: 'DAIRY',
      priceAmount: 2.5,
      currency: 'USD',
    ),
  ],
  flaggedProducts: const [],
);

const _fridge = StorageSpot(
  id: 'spot-1',
  name: 'Fridge',
  type: StorageSpotType.fridge,
);

final _persistedReceipt = PersistedShoppingReceipt(
  id: 'shopping-receipt-1',
  shoppingDate: DateTime(2026, 9, 8),
  storeName: 'SuperMart',
  products: [
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
  storageSpots: const [_fridge],
);

Future<ShoppingReceiptBloc> _buildReprocessedBloc() async {
  final repository = _StubShoppingReceiptRepository(
    Right(_extraction),
    Right(_persistedReceipt),
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
  bloc.add(const ReprocessSelectionToggled(0));
  bloc.add(const ReceiptReprocessSubmitted());
  await bloc.stream.firstWhere(
    (state) => state.status is ShoppingReceiptReprocessSuccess,
  );
  return bloc;
}

Future<void> _pumpReprocessedPage(WidgetTester tester, ShoppingReceiptBloc bloc) {
  final router = GoRouter(
    initialLocation: '/process-receipt/reprocessed-results',
    routes: [
      GoRoute(
        path: '/process-receipt/reprocessed-results',
        builder: (context, state) => const ReceiptReprocessedPage(),
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

void main() {
  testWidgets('shows storeName and shoppingDate', (tester) async {
    final bloc = await _buildReprocessedBloc();

    await _pumpReprocessedPage(tester, bloc);

    expect(find.text('SuperMart'), findsOneWidget);
    expect(find.text('2026-09-08'), findsOneWidget);
  });

  testWidgets(
    'shows every product with its resolved storage spot, and no checkboxes '
    'or reprocess controls',
    (tester) async {
      final bloc = await _buildReprocessedBloc();

      await _pumpReprocessedPage(tester, bloc);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.textContaining('Fridge'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.textContaining('No suggested spot'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Reprocess selected products'),
        findsNothing,
      );
    },
  );

  testWidgets('OK navigates to the space overview for the current space', (
    tester,
  ) async {
    final bloc = await _buildReprocessedBloc();

    await _pumpReprocessedPage(tester, bloc);

    await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
    await tester.pumpAndSettle();

    expect(find.text('OVERVIEW_MARKER_space-1'), findsOneWidget);
  });
}
