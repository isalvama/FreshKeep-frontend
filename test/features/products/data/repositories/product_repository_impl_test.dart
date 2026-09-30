import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/products/data/datasources/product_remote_datasource.dart';
import 'package:fresh_keep_frontend/features/products/data/repositories/product_repository_impl.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/currency.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/moved_product.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_changes.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/product_type.dart';
import 'package:fresh_keep_frontend/features/products/domain/entities/updated_product.dart';

/// Replies with [statusCode] (and [body] as JSON, if any) and records every
/// request it receives.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statusCode, this.body});

  final int statusCode;
  final dynamic body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (body == null) {
      return ResponseBody.fromBytes(const [], statusCode);
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
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

ProductRepositoryImpl _buildRepository(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ProductRepositoryImpl(remoteDataSource: ProductRemoteDataSource(dio));
}

void main() {
  group('ProductRepositoryImpl.deleteProduct', () {
    test(
      'sends DELETE /api/v1/products/<id> and maps 204 to Right(unit)',
      () async {
        final adapter = _RecordingAdapter(statusCode: 204);
        final repository = _buildRepository(adapter);

        final result = await repository.deleteProduct(productId: 'product-1');

        expect(result, const Right<ProductFailure, Unit>(unit));
        expect(adapter.requests, hasLength(1));
        expect(adapter.requests.single.method, 'DELETE');
        expect(adapter.requests.single.path, '/api/v1/products/product-1');
      },
    );
  });

  group('ProductRepositoryImpl.deleteProducts', () {
    test('sends DELETE /api/v1/products with productsIds and maps 204 to '
        'Right(unit)', () async {
      final adapter = _RecordingAdapter(statusCode: 204);
      final repository = _buildRepository(adapter);

      final result = await repository.deleteProducts(
        productIds: ['product-1', 'product-2'],
      );

      expect(result, const Right<ProductFailure, Unit>(unit));
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/products');
      expect(request.data, {
        'productsIds': ['product-1', 'product-2'],
      });
    });
  });

  group('ProductRepositoryImpl status-code-to-failure mapping', () {
    // Each case runs against both endpoints: they share the same mapping.
    final cases = <int, (TypeMatcher<ProductFailure>, String)>{
      400: (
        isA<ProductValidationFailure>(),
        'Some of these products no longer exist.',
      ),
      401: (
        isA<ProductUnauthorizedFailure>(),
        'Your session has expired. Please log in again.',
      ),
      403: (
        isA<ProductForbiddenFailure>(),
        'You are not allowed to perform this action.',
      ),
      409: (
        isA<ProductConflictFailure>(),
        'You are not a participant of this space.',
      ),
    };

    final calls =
        <
          String,
          Future<Either<ProductFailure, Unit>> Function(ProductRepositoryImpl)
        >{
          'deleteProduct': (r) => r.deleteProduct(productId: 'product-1'),
          'deleteProducts': (r) =>
              r.deleteProducts(productIds: ['product-1', 'product-2']),
        };

    for (final call in calls.entries) {
      for (final entry in cases.entries) {
        final status = entry.key;
        final (matcher, defaultMessage) = entry.value;

        test('${call.key}: $status uses the backend detail', () async {
          final repository = _buildRepository(
            _RecordingAdapter(
              statusCode: status,
              body: {'detail': 'backend says $status'},
            ),
          );

          final failure = (await call.value(repository)).getLeft().toNullable();

          expect(failure, matcher);
          expect(failure!.message, 'backend says $status');
        });

        test(
          '${call.key}: $status without detail uses the default message',
          () async {
            final repository = _buildRepository(
              _RecordingAdapter(statusCode: status, body: <String, dynamic>{}),
            );

            final failure = (await call.value(
              repository,
            )).getLeft().toNullable();

            expect(failure, matcher);
            expect(failure!.message, defaultMessage);
          },
        );
      }

      test(
        '${call.key}: connection error maps to ProductNetworkFailure',
        () async {
          final repository = _buildRepository(_ConnectionErrorAdapter());

          final failure = (await call.value(repository)).getLeft().toNullable();

          expect(failure, isA<ProductNetworkFailure>());
        },
      );
    }
  });

  group('ProductRepositoryImpl.updateProduct', () {
    const updatedJson = {
      'productId': 'product-1',
      'name': 'Oat milk',
      'expirationDate': '2026-10-05',
      'productType': 'DAIRY',
      'amount': 2.5,
      'currency': 'EUR',
    };

    test('sends PATCH /api/v1/products/<id> with every changed field and maps '
        '200 to Right(UpdatedProduct)', () async {
      final adapter = _RecordingAdapter(statusCode: 200, body: updatedJson);
      final repository = _buildRepository(adapter);

      final result = await repository.updateProduct(
        productId: 'product-1',
        changes: ProductChanges(
          name: 'Oat milk',
          expirationDate: DateTime(2026, 10, 5),
          productType: ProductType.DAIRY,
          amount: 2.5,
          currency: Currency.EUR,
        ),
      );

      expect(
        result,
        Right<ProductFailure, UpdatedProduct>(
          UpdatedProduct(
            productId: 'product-1',
            name: 'Oat milk',
            expirationDate: DateTime(2026, 10, 5),
            productType: 'DAIRY',
            amount: 2.5,
            currency: 'EUR',
          ),
        ),
      );
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/products/product-1');
      expect(request.data, {
        'name': 'Oat milk',
        'expirationDate': '2026-10-05',
        'productType': 'DAIRY',
        'amount': 2.5,
        'currency': 'EUR',
      });
    });

    test('leaves null fields out of the body', () async {
      final adapter = _RecordingAdapter(statusCode: 200, body: updatedJson);
      final repository = _buildRepository(adapter);

      await repository.updateProduct(
        productId: 'product-1',
        changes: const ProductChanges(
          productType: ProductType.OTHER_FRESH_PRODUCTS,
        ),
      );

      expect(adapter.requests.single.data, {
        'productType': 'OTHER_FRESH_PRODUCTS',
      });
    });

    test('sends the date as yyyy-MM-dd from its local calendar day', () async {
      final adapter = _RecordingAdapter(statusCode: 200, body: updatedJson);
      final repository = _buildRepository(adapter);

      await repository.updateProduct(
        productId: 'product-1',
        changes: ProductChanges(expirationDate: DateTime(2026, 1, 3, 23, 59)),
      );

      expect(adapter.requests.single.data, {'expirationDate': '2026-01-03'});
    });

    test('parses a response with null amount and currency, and an integer '
        'amount', () async {
      final repository = _buildRepository(
        _RecordingAdapter(
          statusCode: 200,
          body: {...updatedJson, 'amount': null, 'currency': null},
        ),
      );

      final product = (await repository.updateProduct(
        productId: 'product-1',
        changes: const ProductChanges(name: 'Oat milk'),
      )).getRight().toNullable();

      expect(product!.amount, isNull);
      expect(product.currency, isNull);

      final intRepository = _buildRepository(
        _RecordingAdapter(statusCode: 200, body: {...updatedJson, 'amount': 3}),
      );
      final intProduct = (await intRepository.updateProduct(
        productId: 'product-1',
        changes: const ProductChanges(amount: 3),
      )).getRight().toNullable();

      expect(intProduct!.amount, 3.0);
    });

    final cases = <int, (TypeMatcher<ProductFailure>, String)>{
      400: (
        isA<ProductValidationFailure>(),
        "This product couldn't be updated. Check the values and try again.",
      ),
      401: (
        isA<ProductUnauthorizedFailure>(),
        'Your session has expired. Please log in again.',
      ),
      403: (
        isA<ProductForbiddenFailure>(),
        'You are not allowed to perform this action.',
      ),
      409: (
        isA<ProductConflictFailure>(),
        'You are not a participant of this space.',
      ),
      500: (
        isA<ProductServerFailure>(),
        'Something went wrong on the server. Try again later.',
      ),
    };

    Future<ProductFailure?> update(ProductRepositoryImpl repository) async =>
        (await repository.updateProduct(
          productId: 'product-1',
          changes: const ProductChanges(name: 'Oat milk'),
        )).getLeft().toNullable();

    for (final entry in cases.entries) {
      final status = entry.key;
      final (matcher, defaultMessage) = entry.value;

      test('$status uses the backend detail', () async {
        final failure = await update(
          _buildRepository(
            _RecordingAdapter(
              statusCode: status,
              body: {'detail': 'backend says $status'},
            ),
          ),
        );

        expect(failure, matcher);
        expect(failure!.message, 'backend says $status');
      });

      test('$status without detail uses the default message', () async {
        final failure = await update(
          _buildRepository(
            _RecordingAdapter(statusCode: status, body: <String, dynamic>{}),
          ),
        );

        expect(failure, matcher);
        expect(failure!.message, defaultMessage);
      });
    }

    test('connection error maps to ProductNetworkFailure', () async {
      final failure = await update(_buildRepository(_ConnectionErrorAdapter()));

      expect(failure, isA<ProductNetworkFailure>());
    });
  });

  group('ProductRepositoryImpl.moveProduct', () {
    const movedJson = {
      'productId': 'product-1',
      'newStorageSpotId': 'spot-2',
      'newExpirationDate': '2026-09-18',
    };

    Future<Either<ProductFailure, MovedProduct>> move(
      ProductRepositoryImpl repository,
    ) => repository.moveProduct(
      productId: 'product-1',
      oldStorageSpotId: 'spot-1',
      newStorageSpotId: 'spot-2',
    );

    test('sends PATCH /api/v1/products/<id>/storage-spot with both spot ids '
        'and maps 200 to Right(MovedProduct)', () async {
      final adapter = _RecordingAdapter(statusCode: 200, body: movedJson);

      final result = await move(_buildRepository(adapter));

      expect(
        result,
        Right<ProductFailure, MovedProduct>(
          MovedProduct(
            productId: 'product-1',
            newStorageSpotId: 'spot-2',
            newExpirationDate: DateTime(2026, 9, 18),
          ),
        ),
      );
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/products/product-1/storage-spot');
      expect(request.data, {
        'oldStorageSpotId': 'spot-1',
        'newStorageSpotId': 'spot-2',
      });
    });

    test('parses newExpirationDate as a local calendar day', () async {
      final moved = (await move(
        _buildRepository(_RecordingAdapter(statusCode: 200, body: movedJson)),
      )).getRight().toNullable();

      expect(moved!.newExpirationDate.isUtc, isFalse);
      expect(
        (
          moved.newExpirationDate.year,
          moved.newExpirationDate.month,
          moved.newExpirationDate.day,
        ),
        (2026, 9, 18),
      );
    });

    final cases = <int, (TypeMatcher<ProductFailure>, String)>{
      400: (
        isA<ProductValidationFailure>(),
        "This product couldn't be moved. Try again.",
      ),
      401: (
        isA<ProductUnauthorizedFailure>(),
        'Your session has expired. Please log in again.',
      ),
      403: (
        isA<ProductForbiddenFailure>(),
        'You are not allowed to perform this action.',
      ),
      409: (
        isA<ProductConflictFailure>(),
        'You are not a participant of this space.',
      ),
      500: (
        isA<ProductServerFailure>(),
        'Something went wrong on the server. Try again later.',
      ),
    };

    for (final entry in cases.entries) {
      final status = entry.key;
      final (matcher, defaultMessage) = entry.value;

      test('$status uses the backend detail', () async {
        final failure = (await move(
          _buildRepository(
            _RecordingAdapter(
              statusCode: status,
              body: {'detail': 'backend says $status'},
            ),
          ),
        )).getLeft().toNullable();

        expect(failure, matcher);
        expect(failure!.message, 'backend says $status');
      });

      test('$status without detail uses the default message', () async {
        final failure = (await move(
          _buildRepository(
            _RecordingAdapter(statusCode: status, body: <String, dynamic>{}),
          ),
        )).getLeft().toNullable();

        expect(failure, matcher);
        expect(failure!.message, defaultMessage);
      });
    }

    test('an AI Server Error 400 shows the backend detail', () async {
      final failure = (await move(
        _buildRepository(
          _RecordingAdapter(
            statusCode: 400,
            body: {
              'title': 'AI Server Error',
              'status': 400,
              'detail': 'The AI service is temporarily unavailable.',
            },
          ),
        ),
      )).getLeft().toNullable();

      expect(failure, isA<ProductValidationFailure>());
      expect(failure!.message, 'The AI service is temporarily unavailable.');
    });

    test('connection error maps to ProductNetworkFailure', () async {
      final failure = (await move(
        _buildRepository(_ConnectionErrorAdapter()),
      )).getLeft().toNullable();

      expect(failure, isA<ProductNetworkFailure>());
    });
  });
}
