import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/data/datasources/shopping_receipt_remote_datasource.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/data/repositories/shopping_receipt_repository_impl.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/persisted_shopping_receipt.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/product_extraction.dart';
import 'package:fresh_keep_frontend/features/shopping_receipt/domain/entities/receipt_extraction_result.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';

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

const _fridge = StorageSpot(
  id: 'spot-1',
  name: 'Fridge',
  type: StorageSpotType.fridge,
);

final _milk = ProductExtraction(
  expirationDate: DateTime(2026, 9, 15),
  productName: 'Milk',
  suggestedStorageSpotId: 'spot-1',
  productType: 'DAIRY',
  priceAmount: 2.5,
  currency: 'USD',
);

final _eggsWithNoSuggestedSpot = ProductExtraction(
  expirationDate: DateTime(2026, 9, 20),
  productName: 'Eggs',
  suggestedStorageSpotId: null,
  productType: 'DAIRY',
  priceAmount: null,
  currency: null,
);

Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
_confirmReceipt(
  ShoppingReceiptRepositoryImpl repository, {
  List<ProductExtraction>? allProducts,
}) {
  return repository.confirmReceipt(
    spaceId: 'space-1',
    shoppingReceiptId: 'shopping-receipt-1',
    receiptImageId: 'receipt-1',
    shoppingDate: DateTime(2026, 9, 8),
    storeName: 'SuperMart',
    allProducts: allProducts ?? [_milk],
    spaceStorageSpots: const [_fridge],
  );
}

final _bread = ProductExtraction(
  expirationDate: DateTime(2026, 9, 20),
  productName: 'Bread',
  suggestedStorageSpotId: 'spot-1',
  productType: 'BAKERY',
  priceAmount: 3.0,
  currency: 'USD',
);

Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>>
_reprocessReceipt(
  ShoppingReceiptRepositoryImpl repository, {
  List<ProductExtraction>? flaggedProducts,
  List<ProductExtraction>? allProducts,
}) {
  return repository.reprocessReceipt(
    spaceId: 'space-1',
    shoppingReceiptId: 'shopping-receipt-1',
    receiptImageId: 'receipt-1',
    shoppingDate: DateTime(2026, 9, 8),
    storeName: 'SuperMart',
    language: 'en',
    flaggedProducts: flaggedProducts ?? [_milk],
    allProducts: allProducts ?? [_milk, _bread],
    spaceStorageSpots: const [_fridge],
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
              'shoppingReceiptId': 'shopping-receipt-1',
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
        expect(extraction!.shoppingReceiptId, 'shopping-receipt-1');
        expect(extraction.receiptImageId, 'receipt-1');
        expect(extraction.storeName, 'SuperMart');
        expect(extraction.suggestedStorageSpots, hasLength(1));
        expect(extraction.productExtractions, hasLength(1));
        expect(extraction.productExtractions.first.productName, 'Milk');
        expect(
          extraction.productExtractions.first.manuallyEditedExpirationDate,
          isFalse,
        );
        expect(extraction.flaggedProducts, isEmpty);
      },
    );

    test(
      'the request is sent as multipart/form-data, overriding the Dio client-wide JSON default',
      () async {
        final adapter = _JsonResponseAdapter(
          statusCode: 201,
          body: {
            'shoppingReceiptId': 'shopping-receipt-1',
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

    test(
      'a response without shoppingReceiptId maps to ShoppingReceiptServerFailure',
      () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 201,
            body: {
              'receiptImageId': 'receipt-1',
              'suggestedStorageSpots': <dynamic>[],
              'purchaseShoppingDate': '2026-09-08',
              'storeName': 'SuperMart',
              'productExtractions': <dynamic>[],
              'flaggedProducts': <dynamic>[],
            },
          ),
        );

        final result = await _processNewReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptServerFailure>(),
        );
      },
    );
  });

  group(
    'ShoppingReceiptRepositoryImpl.confirmReceipt status-code-to-failure mapping',
    () {
      test('400 maps to ShoppingReceiptValidationFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 400, body: {'detail': 'bad body'}),
        );

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptValidationFailure>(),
        );
      });

      test(
        'a 400 with a field-errors map (no detail) surfaces those field errors',
        () async {
          final repository = _buildRepository(
            _JsonResponseAdapter(
              statusCode: 400,
              body: {
                'title': 'Validation Error In Body Data',
                'errors': {
                  'shoppingDate': 'must not be null',
                  'receiptImageId': 'must not be null',
                },
              },
            ),
          );

          final result = await _confirmReceipt(repository);

          final failure =
              result.getLeft().toNullable() as ShoppingReceiptValidationFailure;
          expect(failure.message, contains('shoppingDate: must not be null'));
          expect(failure.message, contains('receiptImageId: must not be null'));
        },
      );

      test('a 400 with neither detail nor field errors falls back to a '
          'confirm-specific message, not the image-upload one', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 400, body: {'title': 'Bad Request'}),
        );

        final result = await _confirmReceipt(repository);

        final failure =
            result.getLeft().toNullable() as ShoppingReceiptValidationFailure;
        expect(failure.message, 'Please check the receipt details.');
      });

      test('401 maps to ShoppingReceiptUnauthorizedFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 401, body: {'detail': 'no token'}),
        );

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptUnauthorizedFailure>(),
        );
      });

      test('403 maps to ShoppingReceiptForbiddenFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 403, body: {'detail': 'wrong role'}),
        );

        final result = await _confirmReceipt(repository);

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

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptConflictFailure>(),
        );
      });

      test('422 maps to ShoppingReceiptUnprocessableFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 422,
            body: {'detail': 'AI could not process'},
          ),
        );

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptUnprocessableFailure>(),
        );
      });

      test('429 maps to ShoppingReceiptRateLimitedFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 429, body: {'detail': 'rate limit'}),
        );

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptRateLimitedFailure>(),
        );
      });

      test('500 maps to ShoppingReceiptServerFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 500, body: {'detail': 'boom'}),
        );

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptServerFailure>(),
        );
      });

      test('connection error maps to ShoppingReceiptNetworkFailure', () async {
        final repository = _buildRepository(_ConnectionErrorAdapter());

        final result = await _confirmReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptNetworkFailure>(),
        );
      });
    },
  );

  group('ShoppingReceiptRepositoryImpl.confirmReceipt success handling', () {
    test(
      'a successful call maps the response to a PersistedShoppingReceipt',
      () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 201,
            body: {
              'id': 'shopping-receipt-1',
              'shoppingDate': '2026-09-08',
              'storeName': 'SuperMart',
              'products': [
                {
                  'id': 'product-1',
                  'productName': 'Milk',
                  'expirationDate': '2026-09-15',
                  'storageSpotId': 'spot-1',
                  'productType': 'DAIRY',
                  'priceAmount': 2.50,
                  'currency': 'USD',
                },
              ],
              'storageSpots': [
                {
                  'storageSpotId': 'spot-1',
                  'storageSpotName': 'Fridge',
                  'storageSpotType': 'FRIDGE',
                },
              ],
            },
          ),
        );

        final result = await _confirmReceipt(repository);

        final persisted = result.getRight().toNullable();
        expect(persisted, isNotNull);
        expect(persisted!.id, 'shopping-receipt-1');
        expect(persisted.storeName, 'SuperMart');
        expect(persisted.products, hasLength(1));
        expect(persisted.products.first.productName, 'Milk');
        expect(persisted.storageSpots, hasLength(1));
      },
    );

    test('a product with a null suggestedStorageSpotId is sent with the first '
        'space storage spot as a fallback', () async {
      final adapter = _JsonResponseAdapter(
        statusCode: 201,
        body: {
          'id': 'shopping-receipt-1',
          'shoppingDate': '2026-09-08',
          'storeName': 'SuperMart',
          'products': <dynamic>[],
          'storageSpots': <dynamic>[],
        },
      );
      final repository = _buildRepository(adapter);

      await _confirmReceipt(
        repository,
        allProducts: [_eggsWithNoSuggestedSpot],
      );

      final sentBody = adapter.capturedOptions?.data as Map<String, dynamic>;
      final sentProducts = sentBody['allProducts'] as List<dynamic>;
      expect((sentProducts.single as Map)['suggestedStorageSpotId'], 'spot-1');
    });

    test(
      'every product is sent with its manuallyEditedExpirationDate flag',
      () async {
        final adapter = _JsonResponseAdapter(
          statusCode: 201,
          body: {
            'id': 'shopping-receipt-1',
            'shoppingDate': '2026-09-08',
            'storeName': 'SuperMart',
            'products': <dynamic>[],
            'storageSpots': <dynamic>[],
          },
        );
        final repository = _buildRepository(adapter);

        await _confirmReceipt(
          repository,
          allProducts: [
            _milk,
            _bread.copyWith(
              expirationDate: DateTime(2026, 9, 25),
              manuallyEditedExpirationDate: true,
            ),
          ],
        );

        final sentBody = adapter.capturedOptions?.data as Map<String, dynamic>;
        final sentProducts = sentBody['allProducts'] as List<dynamic>;
        expect((sentProducts[0] as Map)['manuallyEditedExpirationDate'], false);
        expect((sentProducts[1] as Map)['manuallyEditedExpirationDate'], true);
        expect((sentProducts[1] as Map)['expirationDate'], '2026-09-25');
        expect(sentBody['shoppingReceiptId'], 'shopping-receipt-1');
        expect(sentBody.containsKey('language'), isFalse);
      },
    );
  });

  group(
    'ShoppingReceiptRepositoryImpl.reprocessReceipt status-code-to-failure mapping',
    () {
      test('400 maps to ShoppingReceiptValidationFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 400, body: {'detail': 'bad body'}),
        );

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptValidationFailure>(),
        );
      });

      test('401 maps to ShoppingReceiptUnauthorizedFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 401, body: {'detail': 'no token'}),
        );

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptUnauthorizedFailure>(),
        );
      });

      test('403 maps to ShoppingReceiptForbiddenFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 403, body: {'detail': 'wrong role'}),
        );

        final result = await _reprocessReceipt(repository);

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

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptConflictFailure>(),
        );
      });

      test('422 maps to ShoppingReceiptUnprocessableFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 422,
            body: {'detail': 'AI could not process'},
          ),
        );

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptUnprocessableFailure>(),
        );
      });

      test('429 maps to ShoppingReceiptRateLimitedFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 429, body: {'detail': 'rate limit'}),
        );

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptRateLimitedFailure>(),
        );
      });

      test('500 maps to ShoppingReceiptServerFailure', () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(statusCode: 500, body: {'detail': 'boom'}),
        );

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptServerFailure>(),
        );
      });

      test('connection error maps to ShoppingReceiptNetworkFailure', () async {
        final repository = _buildRepository(_ConnectionErrorAdapter());

        final result = await _reprocessReceipt(repository);

        expect(
          result.getLeft().toNullable(),
          isA<ShoppingReceiptNetworkFailure>(),
        );
      });
    },
  );

  group('ShoppingReceiptRepositoryImpl.reprocessReceipt success handling', () {
    test(
      'a successful call maps the response to a PersistedShoppingReceipt',
      () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 201,
            body: {
              'id': 'shopping-receipt-1',
              'shoppingDate': '2026-09-08',
              'storeName': 'SuperMart',
              'products': [
                {
                  'id': 'product-1',
                  'productName': 'Milk',
                  'expirationDate': '2026-09-15',
                  'storageSpotId': 'spot-1',
                  'productType': 'DAIRY',
                  'priceAmount': 2.50,
                  'currency': 'USD',
                },
              ],
              'storageSpots': [
                {
                  'storageSpotId': 'spot-1',
                  'storageSpotName': 'Fridge',
                  'storageSpotType': 'FRIDGE',
                },
              ],
            },
          ),
        );

        final result = await _reprocessReceipt(repository);

        final persisted = result.getRight().toNullable();
        expect(persisted, isNotNull);
        expect(persisted!.id, 'shopping-receipt-1');
        expect(persisted.products, hasLength(1));
      },
    );

    test(
      'only the checked subset is sent as flaggedProducts while allProducts carries everything',
      () async {
        final adapter = _JsonResponseAdapter(
          statusCode: 201,
          body: {
            'id': 'shopping-receipt-1',
            'shoppingDate': '2026-09-08',
            'storeName': 'SuperMart',
            'products': <dynamic>[],
            'storageSpots': <dynamic>[],
          },
        );
        final repository = _buildRepository(adapter);

        await _reprocessReceipt(
          repository,
          flaggedProducts: [_milk],
          allProducts: [_milk, _bread],
        );

        final sentBody = adapter.capturedOptions?.data as Map<String, dynamic>;
        final sentFlagged = sentBody['flaggedProducts'] as List<dynamic>;
        final sentAll = sentBody['allProducts'] as List<dynamic>;
        expect(sentFlagged, hasLength(1));
        expect((sentFlagged.single as Map)['productName'], 'Milk');
        expect(sentAll, hasLength(2));
        expect(sentBody['language'], 'en');
        expect(sentBody['shoppingReceiptId'], 'shopping-receipt-1');
        for (final product in [...sentFlagged, ...sentAll]) {
          expect((product as Map)['manuallyEditedExpirationDate'], false);
        }
      },
    );

    test('a product with a null suggestedStorageSpotId is sent with the first '
        'space storage spot as a fallback', () async {
      final adapter = _JsonResponseAdapter(
        statusCode: 201,
        body: {
          'id': 'shopping-receipt-1',
          'shoppingDate': '2026-09-08',
          'storeName': 'SuperMart',
          'products': <dynamic>[],
          'storageSpots': <dynamic>[],
        },
      );
      final repository = _buildRepository(adapter);

      await _reprocessReceipt(
        repository,
        flaggedProducts: [_eggsWithNoSuggestedSpot],
        allProducts: [_eggsWithNoSuggestedSpot],
      );

      final sentBody = adapter.capturedOptions?.data as Map<String, dynamic>;
      final sentFlagged = sentBody['flaggedProducts'] as List<dynamic>;
      expect((sentFlagged.single as Map)['suggestedStorageSpotId'], 'spot-1');
    });
  });
}
