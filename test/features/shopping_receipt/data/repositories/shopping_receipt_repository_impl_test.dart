import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/data/datasources/shopping_receipt_remote_datasource.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/data/repositories/shopping_receipt_repository_impl.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';

class _JsonResponseAdapter implements HttpClientAdapter {
  _JsonResponseAdapter({required this.statusCode, this.body});

  final int statusCode;
  final dynamic body;
  RequestOptions? capturedOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedOptions = options;
    final bytes = utf8.encode(jsonEncode(body ?? {}));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ConnectionErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Failed host lookup',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mirrors DioClient's BaseOptions (Content-Type: application/json set for
/// every request) so this test can verify Dio's per-request multipart
/// content-type override actually wins over that base header.
ShoppingReceiptRepositoryImpl _buildRepository(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(headers: {'Content-Type': 'application/json'}))
    ..httpClientAdapter = adapter;
  return ShoppingReceiptRepositoryImpl(
    remoteDataSource: ShoppingReceiptRemoteDataSource(dio),
  );
}

late File _tempImageFile;

Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>>
_processNewReceipt(ShoppingReceiptRepositoryImpl repository) {
  return repository.processNewReceipt(
    spaceId: 'space-1',
    imagePath: _tempImageFile.path,
    language: 'en',
  );
}

void main() {
  setUpAll(() async {
    _tempImageFile = File(
      '${Directory.systemTemp.path}/shopping_receipt_repository_impl_test.jpg',
    );
    await _tempImageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
  });

  tearDownAll(() async {
    if (await _tempImageFile.exists()) {
      await _tempImageFile.delete();
    }
  });

  group('ShoppingReceiptRepositoryImpl status-code-to-failure mapping', () {
    test('400 maps to ShoppingReceiptValidationFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 400, body: {'detail': 'bad file'}),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptValidationFailure>(),
      );
    });

    test('401 maps to ShoppingReceiptUnauthorizedFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 401, body: {'detail': 'no token'}),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptUnauthorizedFailure>(),
      );
    });

    test('403 maps to ShoppingReceiptForbiddenFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 403, body: {'detail': 'wrong role'}),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptForbiddenFailure>(),
      );
    });

    test('409 maps to ShoppingReceiptConflictFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 409,
          body: {'detail': 'not a participant'},
        ),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptConflictFailure>(),
      );
    });

    test('422 maps to ShoppingReceiptUnprocessableFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 422,
          body: {'detail': 'unreadable image'},
        ),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptUnprocessableFailure>(),
      );
    });

    test('429 maps to ShoppingReceiptRateLimitedFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 429, body: {'detail': 'rate limit'}),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptRateLimitedFailure>(),
      );
    });

    test('500 maps to ShoppingReceiptServerFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 500, body: {'detail': 'boom'}),
      );

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptServerFailure>(),
      );
    });

    test('connection error maps to ShoppingReceiptNetworkFailure', () async {
      final repository = _buildRepository(_ConnectionErrorAdapter());

      final result = await _processNewReceipt(repository);

      expect(
        result.getLeft().toNullable(),
        isA<ShoppingReceiptNetworkFailure>(),
      );
    });
  });

  group('ShoppingReceiptRepositoryImpl.processNewReceipt success handling', () {
    test(
      'a successful call maps the response to a ReceiptExtractionResult',
      () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 201,
            body: {
              'receiptImageId': 'receipt-1',
              'suggestedStorageSpots': [
                {
                  'storageSpotId': 'spot-1',
                  'storageSpotName': 'Fridge',
                  'storageSpotType': 'FRIDGE',
                },
              ],
              'purchaseShoppingDate': '2026-09-08',
              'storeName': 'SuperMart',
              'productExtractions': [
                {
                  'expirationDate': '2026-09-15',
                  'productName': 'Milk',
                  'suggestedStorageSpotId': 'spot-1',
                  'productType': 'DAIRY',
                  'priceAmount': 2.50,
                  'currency': 'USD',
                },
              ],
              'flaggedProducts': <dynamic>[],
            },
          ),
        );

        final result = await _processNewReceipt(repository);

        final extraction = result.getRight().toNullable();
        expect(extraction, isNotNull);
        expect(extraction!.receiptImageId, 'receipt-1');
        expect(extraction.storeName, 'SuperMart');
        expect(extraction.suggestedStorageSpots, hasLength(1));
        expect(extraction.productExtractions, hasLength(1));
        expect(extraction.productExtractions.first.productName, 'Milk');
        expect(extraction.flaggedProducts, isEmpty);
      },
    );

    test(
      'the request is sent as multipart/form-data, overriding the Dio client-wide JSON default',
      () async {
        final adapter = _JsonResponseAdapter(
          statusCode: 201,
          body: {
            'receiptImageId': 'receipt-1',
            'suggestedStorageSpots': <dynamic>[],
            'purchaseShoppingDate': '2026-09-08',
            'storeName': 'SuperMart',
            'productExtractions': <dynamic>[],
            'flaggedProducts': <dynamic>[],
          },
        );
        final repository = _buildRepository(adapter);

        await _processNewReceipt(repository);

        expect(
          adapter.capturedOptions?.contentType,
          startsWith('multipart/form-data'),
        );
      },
    );
  });
}
