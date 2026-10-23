import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/space_overview/data/datasources/space_overview_remote_datasource.dart';
import 'package:fresh_keep_frontend/features/space_overview/data/repositories/space_overview_repository_impl.dart';

class _JsonResponseAdapter implements HttpClientAdapter {
  _JsonResponseAdapter({required this.statusCode, this.body});

  final int statusCode;
  final dynamic body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

SpaceOverviewRepositoryImpl _buildRepository(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return SpaceOverviewRepositoryImpl(
    remoteDataSource: SpaceOverviewRemoteDataSource(dio),
  );
}

void main() {
  group('SpaceOverviewRepositoryImpl status-code-to-failure mapping', () {
    test('400 maps to SpaceOverviewValidationFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 400, body: {'detail': 'bad id'}),
      );

      final result = await repository.getSpaceOverview(spaceId: 'space-1');

      expect(
        result.getLeft().toNullable(),
        isA<SpaceOverviewValidationFailure>(),
      );
    });

    test('401 maps to SpaceOverviewUnauthorizedFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 401, body: {'detail': 'no token'}),
      );

      final result = await repository.getSpaceOverview(spaceId: 'space-1');

      expect(
        result.getLeft().toNullable(),
        isA<SpaceOverviewUnauthorizedFailure>(),
      );
    });

    test('403 maps to SpaceOverviewForbiddenFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 403, body: {'detail': 'wrong role'}),
      );

      final result = await repository.getSpaceOverview(spaceId: 'space-1');

      expect(
        result.getLeft().toNullable(),
        isA<SpaceOverviewForbiddenFailure>(),
      );
    });

    test('409 maps to SpaceOverviewConflictFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 409,
          body: {'detail': 'not a participant'},
        ),
      );

      final result = await repository.getSpaceOverview(spaceId: 'space-1');

      expect(
        result.getLeft().toNullable(),
        isA<SpaceOverviewConflictFailure>(),
      );
    });

    test('connection error maps to SpaceOverviewNetworkFailure', () async {
      final repository = _buildRepository(_ConnectionErrorAdapter());

      final result = await repository.getSpaceOverview(spaceId: 'space-1');

      expect(
        result.getLeft().toNullable(),
        isA<SpaceOverviewNetworkFailure>(),
      );
    });
  });

  group('SpaceOverviewRepositoryImpl.getSpaceOverview success handling', () {
    test(
      'a successful call maps the response to a SpaceOverview',
      () async {
        final repository = _buildRepository(
          _JsonResponseAdapter(
            statusCode: 200,
            body: {
              'id': 'space-1',
              'name': 'Kitchen',
              'emoji': '🏠',
              'storageSpots': [
                {
                  'storageSpotId': 'spot-1',
                  'storageSpotName': 'Fridge',
                  'storageSpotType': 'FRIDGE',
                },
              ],
              'productResults': [
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
            },
          ),
        );

        final result = await repository.getSpaceOverview(spaceId: 'space-1');

        final overview = result.getRight().toNullable();
        expect(overview, isNotNull);
        expect(overview!.id, 'space-1');
        expect(overview.name, 'Kitchen');
        expect(overview.emoji, '🏠');
        expect(overview.storageSpots, hasLength(1));
        expect(overview.productResults, hasLength(1));
        expect(overview.productResults.first.productName, 'Milk');
      },
    );

    test('an empty productResults list maps to an empty list, not an error', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 200,
          body: {
            'id': 'space-1',
            'name': 'Kitchen',
            'emoji': '🏠',
            'storageSpots': <dynamic>[],
            'productResults': <dynamic>[],
          },
        ),
      );

      final result = await repository.getSpaceOverview(spaceId: 'space-1');

      final overview = result.getRight().toNullable();
      expect(overview, isNotNull);
      expect(overview!.productResults, isEmpty);
    });
  });
}
