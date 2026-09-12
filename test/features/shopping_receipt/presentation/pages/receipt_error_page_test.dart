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
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/pages/receipt_error_page.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:go_router/go_router.dart';

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

Future<ShoppingReceiptBloc> _buildFailedBloc(String message) async {
  final bloc = ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      _StubShoppingReceiptRepository(
        Left(ShoppingReceiptUnprocessableFailure(message)),
      ),
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
}
