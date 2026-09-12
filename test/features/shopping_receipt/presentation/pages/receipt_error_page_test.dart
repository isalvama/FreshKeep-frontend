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
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/receipt_error_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
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
  }) async => confirmResult!;

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
  }) async => reprocessResult!;
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

Future<ShoppingReceiptBloc> _buildFailedBloc(String message) async {
  final repository = _StubShoppingReceiptRepository(
    Left(ShoppingReceiptUnprocessableFailure(message)),
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
    (state) => state.status is ShoppingReceiptProcessFailure,
  );
  return bloc;
}

Future<ShoppingReceiptBloc> _buildConfirmFailedBloc(String message) async {
  final repository = _StubShoppingReceiptRepository(
    Right(_extraction),
    confirmResult: Left(ShoppingReceiptServerFailure(message)),
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
  bloc.add(const ReceiptConfirmSubmitted());
  await bloc.stream.firstWhere(
    (state) => state.status is ShoppingReceiptConfirmFailure,
  );
  return bloc;
}

Future<ShoppingReceiptBloc> _buildReprocessFailedBloc(String message) async {
  final repository = _StubShoppingReceiptRepository(
    Right(_extraction),
    reprocessResult: Left(ShoppingReceiptRateLimitedFailure(message)),
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
    (state) => state.status is ShoppingReceiptReprocessFailure,
  );
  return bloc;
}

Future<void> _pumpErrorPage(WidgetTester tester, ShoppingReceiptBloc bloc) {
  final router = GoRouter(
    initialLocation: '/process-receipt/error',
    routes: [
      GoRoute(
        path: '/process-receipt/error',
        builder: (context, state) => const ReceiptErrorPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('HOME_MARKER'),
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
  testWidgets("shows the failure's message", (tester) async {
    final bloc = await _buildFailedBloc("That doesn't look like a receipt.");

    await _pumpErrorPage(tester, bloc);

    expect(find.text("That doesn't look like a receipt."), findsOneWidget);
  });

  testWidgets('OK navigates to /home', (tester) async {
    final bloc = await _buildFailedBloc('Network error.');

    await _pumpErrorPage(tester, bloc);

    await tester.tap(find.widgetWithText(ElevatedButton, 'OK'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_MARKER'), findsOneWidget);
  });

  testWidgets("shows a confirm failure's message", (tester) async {
    final bloc = await _buildConfirmFailedBloc('Something went wrong.');

    await _pumpErrorPage(tester, bloc);

    expect(find.text('Something went wrong.'), findsOneWidget);
  });

  testWidgets("shows a reprocess failure's message", (tester) async {
    final bloc = await _buildReprocessFailedBloc('Too many requests.');

    await _pumpErrorPage(tester, bloc);

    expect(find.text('Too many requests.'), findsOneWidget);
  });
}
