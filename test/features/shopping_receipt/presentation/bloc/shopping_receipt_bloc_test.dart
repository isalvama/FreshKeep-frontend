import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_shopping_receipt.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/product_extraction.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/repositories/shopping_receipt_repository.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/usecases/process_new_shopping_receipt_usecase.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';

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

ShoppingReceiptBloc _buildBloc(
  Either<ShoppingReceiptFailure, ReceiptExtractionResult> result,
) {
  return ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      _StubShoppingReceiptRepository(result),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial state has no space/image selected and status is initial', () {
    final bloc = _buildBloc(Right(_extraction));

    expect(bloc.state.spaceId, isNull);
    expect(bloc.state.imagePath, isNull);
    expect(bloc.state.status, isA<ShoppingReceiptInitial>());
    expect(bloc.state.selectedForReprocess, isEmpty);

    bloc.close();
  });

  test('SpaceForReceiptSelected stores the spaceId', () async {
    final bloc = _buildBloc(Right(_extraction));

    bloc.add(const SpaceForReceiptSelected('space-1'));
    await bloc.stream.first;

    expect(bloc.state.spaceId, 'space-1');

    bloc.close();
  });

  test('ReceiptImagePicked stores the imagePath', () async {
    final bloc = _buildBloc(Right(_extraction));

    bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
    await bloc.stream.first;

    expect(bloc.state.imagePath, '/tmp/receipt.jpg');

    bloc.close();
  });

  test(
    'ReceiptProcessingSubmitted emits Processing then ProcessSuccess on success',
    () async {
      final bloc = _buildBloc(Right(_extraction));
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const SpaceForReceiptSelected('space-1'));
      bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
      bloc.add(const ReceiptProcessingSubmitted());

      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptProcessSuccess,
      );

      expect(emittedStatuses.whereType<ShoppingReceiptProcessing>(), hasLength(1));
      final successStatus =
          emittedStatuses.last as ShoppingReceiptProcessSuccess;
      expect(successStatus.result, _extraction);

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'ReceiptProcessingSubmitted emits Processing then ProcessFailure on failure',
    () async {
      const failure = ShoppingReceiptUnprocessableFailure(
        "That doesn't look like a receipt.",
      );
      final bloc = _buildBloc(const Left(failure));
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const SpaceForReceiptSelected('space-1'));
      bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
      bloc.add(const ReceiptProcessingSubmitted());

      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptProcessFailure,
      );

      expect(emittedStatuses.whereType<ShoppingReceiptProcessing>(), hasLength(1));
      final failureStatus =
          emittedStatuses.last as ShoppingReceiptProcessFailure;
      expect(failureStatus.message, failure.message);

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'ReprocessSelectionToggled toggles membership in selectedForReprocess',
    () async {
      final bloc = _buildBloc(Right(_extraction));
      final emitted = bloc.stream.take(2).toList();

      bloc.add(const ReprocessSelectionToggled(0));
      bloc.add(const ReprocessSelectionToggled(0));

      final states = await emitted;
      expect(states[0].selectedForReprocess, {0});
      expect(states[1].selectedForReprocess, isEmpty);

      bloc.close();
    },
  );

  test('ShoppingReceiptFlowReset returns to the initial state', () async {
    final bloc = _buildBloc(Right(_extraction));

    bloc.add(const SpaceForReceiptSelected('space-1'));
    bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
    await bloc.stream.take(2).last;

    bloc.add(const ShoppingReceiptFlowReset());
    final resetState = await bloc.stream.first;

    expect(resetState, ShoppingReceiptState.initial());

    bloc.close();
  });
}
