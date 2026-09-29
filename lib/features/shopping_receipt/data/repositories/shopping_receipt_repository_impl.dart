import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../spaces/domain/entities/storage_spot.dart';
import '../../domain/entities/persisted_shopping_receipt.dart';
import '../../domain/entities/product_extraction.dart';
import '../../domain/entities/receipt_extraction_result.dart';
import '../../domain/repositories/shopping_receipt_repository.dart';
import '../datasources/shopping_receipt_remote_datasource.dart';

class ShoppingReceiptRepositoryImpl implements ShoppingReceiptRepository {
  final ShoppingReceiptRemoteDataSource remoteDataSource;

  const ShoppingReceiptRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
  processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async {
    try {
      final response = await remoteDataSource.processNewReceipt(
        spaceId: spaceId,
        imagePath: imagePath,
        language: language,
      );
      return Right(response.toEntity());
    } on DioException catch (e) {
      return Left(
        _mapDioException(
          e,
          validationFallback: 'Please check the selected image.',
        ),
      );
    } on TypeError {
      // A required field (e.g. shoppingReceiptId) is missing or mistyped.
      return const Left(_unexpectedResponseFailure);
    } on FormatException {
      // A date field could not be parsed.
      return const Left(_unexpectedResponseFailure);
    }
  }

  static const _unexpectedResponseFailure = ShoppingReceiptServerFailure(
    'Unexpected response from the server. Please try again.',
  );

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  confirmReceipt({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) async {
    try {
      final response = await remoteDataSource.confirmReceipt(
        spaceId: spaceId,
        shoppingReceiptId: shoppingReceiptId,
        receiptImageId: receiptImageId,
        shoppingDate: shoppingDate,
        storeName: storeName,
        allProducts: allProducts,
        spaceStorageSpots: spaceStorageSpots,
      );
      return Right(response.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  @override
  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
  reprocessReceipt({
    required String spaceId,
    required String shoppingReceiptId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  }) async {
    try {
      final response = await remoteDataSource.reprocessReceipt(
        spaceId: spaceId,
        shoppingReceiptId: shoppingReceiptId,
        receiptImageId: receiptImageId,
        shoppingDate: shoppingDate,
        storeName: storeName,
        language: language,
        flaggedProducts: flaggedProducts,
        allProducts: allProducts,
        spaceStorageSpots: spaceStorageSpots,
      );
      return Right(response.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  ShoppingReceiptFailure _mapDioException(
    DioException e, {
    String validationFallback = 'Please check the receipt details.',
  }) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;
    final fieldErrors = data is Map ? data['errors'] as Map? : null;
    final fieldErrorsSummary = (fieldErrors != null && fieldErrors.isNotEmpty)
        ? fieldErrors.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('; ')
        : null;

    switch (status) {
      case 400:
        return ShoppingReceiptValidationFailure(
          detail ?? fieldErrorsSummary ?? validationFallback,
        );
      case 401:
        return ShoppingReceiptUnauthorizedFailure(
          detail ?? 'Your session has expired. Please log in again.',
        );
      case 403:
        return ShoppingReceiptForbiddenFailure(
          detail ?? 'You are not allowed to perform this action.',
        );
      case 409:
        return ShoppingReceiptConflictFailure(
          detail ?? 'You are not a participant of this space.',
        );
      case 422:
        return ShoppingReceiptUnprocessableFailure(
          detail ?? "That doesn't look like a receipt. Try a clearer photo.",
        );
      case 429:
        return ShoppingReceiptRateLimitedFailure(
          detail ?? 'Too many requests. Please try again shortly.',
        );
      case 500:
        return ShoppingReceiptServerFailure(
          detail ?? 'Something went wrong. Please try again.',
        );
      default:
        return ShoppingReceiptNetworkFailure(
          e.message ?? 'Network error. Please check your connection.',
        );
    }
  }
}
