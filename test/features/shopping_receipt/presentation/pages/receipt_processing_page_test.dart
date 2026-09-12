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
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/receipt_processing_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:go_router/go_router.dart';

class _PendingShoppingReceiptRepository implements ShoppingReceiptRepository {
  final Completer<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  completer = Completer();

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) => completer.future;

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
  }) => throw UnimplementedError();
}

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
  }) => throw UnimplementedError();
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

ShoppingReceiptBloc _buildReadyBloc(ShoppingReceiptRepository repository) {
  final bloc = ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      repository,
    ),
  );
  bloc.add(const SpaceForReceiptSelected('space-1'));
  bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
  return bloc;
}

Future<void> _pumpProcessingPage(
  WidgetTester tester,
  ShoppingReceiptBloc bloc,
) async {
  final router = GoRouter(
    initialLocation: '/process-receipt/processing',
    routes: [
      GoRoute(
        path: '/process-receipt/processing',
        builder: (context, state) => const ReceiptProcessingPage(),
      ),
      GoRoute(
        path: '/process-receipt/results',
        builder: (context, state) => const Text('RESULTS_MARKER'),
      ),
      GoRoute(
        path: '/process-receipt/error',
        builder: (context, state) => const Text('ERROR_MARKER'),
      ),
    ],
  );

  await tester.pumpWidget(
    BlocProvider<ShoppingReceiptBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator while processing', (tester) async {
    final bloc = _buildReadyBloc(_PendingShoppingReceiptRepository());

    await _pumpProcessingPage(tester, bloc);
    bloc.add(const ReceiptProcessingSubmitted());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('navigates to the results screen on success', (tester) async {
    final bloc = _buildReadyBloc(
      _StubShoppingReceiptRepository(Right(_extraction)),
    );

    await _pumpProcessingPage(tester, bloc);
    bloc.add(const ReceiptProcessingSubmitted());
    await tester.pumpAndSettle();

    expect(find.text('RESULTS_MARKER'), findsOneWidget);
  });

  testWidgets(
    'a state change that stays within ProcessSuccess (e.g. a reprocess '
    'selection toggle on the still-mounted bloc) does not re-navigate',
    (tester) async {
      final bloc = _buildReadyBloc(
        _StubShoppingReceiptRepository(Right(_extraction)),
      );

      await _pumpProcessingPage(tester, bloc);
      bloc.add(const ReceiptProcessingSubmitted());
      await tester.pumpAndSettle();

      expect(find.text('RESULTS_MARKER'), findsOneWidget);

      bloc.add(const ReprocessSelectionToggled(0));
      await tester.pumpAndSettle();

      expect(find.text('RESULTS_MARKER'), findsOneWidget);
    },
  );

  testWidgets('navigates to the error screen on failure', (tester) async {
    final bloc = _buildReadyBloc(
      _StubShoppingReceiptRepository(
        const Left(ShoppingReceiptUnprocessableFailure("Can't read this.")),
      ),
    );

    await _pumpProcessingPage(tester, bloc);
    bloc.add(const ReceiptProcessingSubmitted());
    await tester.pumpAndSettle();

    expect(find.text('ERROR_MARKER'), findsOneWidget);
  });
}
