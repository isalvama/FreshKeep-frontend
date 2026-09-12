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
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';

class _StubShoppingReceiptRepository implements ShoppingReceiptRepository {
  _StubShoppingReceiptRepository({
    this.processResult,
    this.confirmResults = const [],
    this.reprocessResults = const [],
  });

  final Either<ShoppingReceiptFailure, ReceiptExtractionResult>? processResult;
  final List<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmResults;
  final List<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessResults;
  int _confirmCallCount = 0;
  int _reprocessCallCount = 0;

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async => processResult!;

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) async {
    final result = confirmResults[_confirmCallCount];
    if (_confirmCallCount < confirmResults.length - 1) _confirmCallCount++;
    return result;
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
  }) async {
    final result = reprocessResults[_reprocessCallCount];
    if (_reprocessCallCount < reprocessResults.length - 1) {
      _reprocessCallCount++;
    }
    return result;
  }
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
  ],
  storageSpots: const [],
);

ShoppingReceiptBloc _buildBloc(
  Either<ShoppingReceiptFailure, ReceiptExtractionResult> processResult, {
  List<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmResults = const [],
  List<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessResults = const [],
}) {
  final repository = _StubShoppingReceiptRepository(
    processResult: processResult,
    confirmResults: confirmResults,
    reprocessResults: reprocessResults,
  );
  return ShoppingReceiptBloc(
    processNewShoppingReceiptUseCase: ProcessNewShoppingReceiptUseCase(
      repository,
    ),
    confirmShoppingReceiptUseCase: ConfirmShoppingReceiptUseCase(repository),
    reprocessShoppingReceiptUseCase: ReprocessShoppingReceiptUseCase(
      repository,
    ),
  );
}

Future<ShoppingReceiptBloc> _buildBlocAtProcessSuccess({
  List<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmResults = const [],
  List<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessResults = const [],
}) async {
  final bloc = _buildBloc(
    Right(_extraction),
    confirmResults: confirmResults,
    reprocessResults: reprocessResults,
  );
  bloc.add(const SpaceForReceiptSelected('space-1'));
  bloc.add(const ReceiptImagePicked('/tmp/receipt.jpg'));
  bloc.add(const ReceiptProcessingSubmitted());
  await bloc.stream.firstWhere(
    (state) => state.status is ShoppingReceiptProcessSuccess,
  );
  return bloc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial state has no space/image selected and status is initial', () {
    final bloc = _buildBloc(Right(_extraction));

    expect(bloc.state.spaceId, isNull);
    expect(bloc.state.imagePath, isNull);
    expect(bloc.state.status, isA<ShoppingReceiptInitial>());
    expect(bloc.state.extraction, isNull);
    expect(bloc.state.reprocessedReceipt, isNull);
    expect(bloc.state.selectedForReprocess, isEmpty);
    expect(bloc.state.consecutiveFailureCount, 0);

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
      expect(bloc.state.status, isA<ShoppingReceiptProcessSuccess>());
      expect(bloc.state.extraction, _extraction);

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

  test(
    'ShoppingReceiptFlowReset clears extraction, reprocessedReceipt, and the failure counter',
    () async {
      final bloc = await _buildBlocAtProcessSuccess(
        confirmResults: [
          const Left(ShoppingReceiptServerFailure('boom')),
        ],
        reprocessResults: [Right(_persistedReceipt)],
      );

      bloc.add(const ReceiptConfirmSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptConfirmFailure,
      );
      expect(bloc.state.consecutiveFailureCount, 1);

      bloc.add(const ReprocessSelectionToggled(0));
      bloc.add(const ReceiptReprocessSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptReprocessSuccess,
      );
      expect(bloc.state.reprocessedReceipt, _persistedReceipt);

      bloc.add(const ShoppingReceiptFlowReset());
      final resetState = await bloc.stream.first;

      expect(resetState, ShoppingReceiptState.initial());

      bloc.close();
    },
  );

  test(
    'ReceiptConfirmSubmitted emits Confirming then ConfirmSuccess and resets the failure counter',
    () async {
      final bloc = await _buildBlocAtProcessSuccess(
        confirmResults: [Right(_persistedReceipt)],
      );
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const ReceiptConfirmSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptConfirmSuccess,
      );

      expect(emittedStatuses.whereType<ShoppingReceiptConfirming>(), hasLength(1));
      expect(bloc.state.consecutiveFailureCount, 0);
      // extraction is retained so the Results screen keeps rendering.
      expect(bloc.state.extraction, _extraction);

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'ReceiptConfirmSubmitted emits Confirming then ConfirmFailure and increments the failure counter',
    () async {
      const failure = ShoppingReceiptServerFailure('Something went wrong.');
      final bloc = await _buildBlocAtProcessSuccess(
        confirmResults: [const Left(failure)],
      );

      bloc.add(const ReceiptConfirmSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptConfirmFailure,
      );

      final failureStatus =
          bloc.state.status as ShoppingReceiptConfirmFailure;
      expect(failureStatus.message, failure.message);
      expect(bloc.state.consecutiveFailureCount, 1);
      // extraction is retained so the Results screen keeps rendering.
      expect(bloc.state.extraction, _extraction);

      bloc.close();
    },
  );

  test(
    'ReceiptReprocessSubmitted emits Reprocessing then ReprocessSuccess, '
    'stores reprocessedReceipt, and resets the failure counter',
    () async {
      final bloc = await _buildBlocAtProcessSuccess(
        reprocessResults: [Right(_persistedReceipt)],
      );
      final emittedStatuses = <Object>[];
      final subscription = bloc.stream.listen(
        (state) => emittedStatuses.add(state.status),
      );

      bloc.add(const ReprocessSelectionToggled(0));
      bloc.add(const ReceiptReprocessSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptReprocessSuccess,
      );

      expect(emittedStatuses.whereType<ShoppingReceiptReprocessing>(), hasLength(1));
      expect(bloc.state.reprocessedReceipt, _persistedReceipt);
      expect(bloc.state.consecutiveFailureCount, 0);

      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'ReceiptReprocessSubmitted emits Reprocessing then ReprocessFailure and increments the failure counter',
    () async {
      const failure = ShoppingReceiptRateLimitedFailure('Slow down.');
      final bloc = await _buildBlocAtProcessSuccess(
        reprocessResults: [const Left(failure)],
      );

      bloc.add(const ReprocessSelectionToggled(0));
      bloc.add(const ReceiptReprocessSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptReprocessFailure,
      );

      final failureStatus =
          bloc.state.status as ShoppingReceiptReprocessFailure;
      expect(failureStatus.message, failure.message);
      expect(bloc.state.consecutiveFailureCount, 1);

      bloc.close();
    },
  );

  test(
    'two consecutive confirm/reprocess failures bring the counter to 2',
    () async {
      const confirmFailure = ShoppingReceiptServerFailure('boom');
      const reprocessFailure = ShoppingReceiptRateLimitedFailure('slow down');
      final bloc = await _buildBlocAtProcessSuccess(
        confirmResults: [const Left(confirmFailure)],
        reprocessResults: [const Left(reprocessFailure)],
      );

      bloc.add(const ReceiptConfirmSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptConfirmFailure,
      );
      expect(bloc.state.consecutiveFailureCount, 1);

      bloc.add(const ReprocessSelectionToggled(0));
      bloc.add(const ReceiptReprocessSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptReprocessFailure,
      );
      expect(bloc.state.consecutiveFailureCount, 2);

      bloc.close();
    },
  );

  test(
    'a success after a failure resets the counter back to 0',
    () async {
      const confirmFailure = ShoppingReceiptServerFailure('boom');
      final bloc = await _buildBlocAtProcessSuccess(
        confirmResults: [
          const Left(confirmFailure),
          Right(_persistedReceipt),
        ],
      );

      bloc.add(const ReceiptConfirmSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptConfirmFailure,
      );
      expect(bloc.state.consecutiveFailureCount, 1);

      bloc.add(const ReceiptConfirmSubmitted());
      await bloc.stream.firstWhere(
        (state) => state.status is ShoppingReceiptConfirmSuccess,
      );
      expect(bloc.state.consecutiveFailureCount, 0);

      bloc.close();
    },
  );
}
