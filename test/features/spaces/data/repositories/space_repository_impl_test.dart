import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/spaces/data/datasources/space_remote_datasource.dart';
import 'package:fresh_keep_frontend/features/spaces/data/repositories/space_repository_impl.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/space.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_input.dart';
import 'package:fresh_keep_frontend/features/spaces/domain/entities/storage_spot_type.dart';

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

SpaceRepositoryImpl _buildRepository(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return SpaceRepositoryImpl(remoteDataSource: SpaceRemoteDataSource(dio));
}

Future<Either<SpaceFailure, Space>> _createSpace(SpaceRepositoryImpl repository) {
  return repository.createSpace(
    spaceName: 'Kitchen',
    emoji: '🏠',
    storageSpots: const [
      StorageSpotInput(name: 'Main Shelf', type: StorageSpotType.shelf),
    ],
  );
}

Future<Either<SpaceFailure, List<Space>>> _getUserSpaces(
  SpaceRepositoryImpl repository,
) {
  return repository.getUserSpaces();
}

void main() {
  group('SpaceRepositoryImpl status-code-to-failure mapping', () {
    test('400 maps to SpaceValidationFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 400, body: {'detail': 'bad input'}),
      );

      final result = await _createSpace(repository);

      expect(result.getLeft().toNullable(), isA<SpaceValidationFailure>());
    });

    test('401 maps to SpaceUnauthorizedFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 401, body: {'detail': 'no token'}),
      );

      final result = await _createSpace(repository);

      expect(result.getLeft().toNullable(), isA<SpaceUnauthorizedFailure>());
    });

    test('403 maps to SpaceForbiddenFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 403, body: {'detail': 'wrong role'}),
      );

      final result = await _createSpace(repository);

      expect(result.getLeft().toNullable(), isA<SpaceForbiddenFailure>());
    });

    test('500 maps to SpaceServerFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 500, body: {'detail': 'boom'}),
      );

      final result = await _createSpace(repository);

      expect(result.getLeft().toNullable(), isA<SpaceServerFailure>());
    });

    test('connection error maps to SpaceNetworkFailure', () async {
      final repository = _buildRepository(_ConnectionErrorAdapter());

      final result = await _createSpace(repository);

      expect(result.getLeft().toNullable(), isA<SpaceNetworkFailure>());
    });
  });

  group('SpaceRepositoryImpl.createSpace success handling', () {
    test('a successful creation maps the response to a Space, keeping the submitted emoji', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 201,
          body: {
            'id': 'space-1',
            'spaceName': 'Kitchen',
            'emoji': '🏠',
            'storageSpots': [
              {
                'storageSpotId': 'spot-1',
                'storageSpotName': 'Main Shelf',
                'storageSpotType': 'SHELF',
              },
            ],
            'creatorId': 'user-1',
            'participantIds': ['user-1'],
          },
        ),
      );

      final result = await _createSpace(repository);

      final space = result.getRight().toNullable();
      expect(space, isNotNull);
      expect(space!.id, 'space-1');
      expect(space.spaceName, 'Kitchen');
      expect(space.emoji, '🏠');
      expect(space.storageSpots, hasLength(1));
      expect(space.storageSpots.first.name, 'Main Shelf');
      expect(space.storageSpots.first.type, StorageSpotType.shelf);
    });
  });

  group('SpaceRepositoryImpl.getUserSpaces', () {
    test('a successful call with items maps to a list of Space', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 200,
          body: [
            {
              'id': 'space-1',
              'spaceName': 'Kitchen',
              'emoji': '🏠',
              'storageSpots': [
                {
                  'storageSpotId': 'spot-1',
                  'storageSpotName': 'Main Shelf',
                  'storageSpotType': 'SHELF',
                },
              ],
              'creatorId': 'user-1',
              'participantIds': ['user-1'],
            },
          ],
        ),
      );

      final result = await _getUserSpaces(repository);

      final spaces = result.getRight().toNullable();
      expect(spaces, isNotNull);
      expect(spaces, hasLength(1));
      expect(spaces!.first.id, 'space-1');
      expect(spaces.first.emoji, '🏠');
    });

    test('a successful call with no spaces maps to an empty list', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 200, body: <dynamic>[]),
      );

      final result = await _getUserSpaces(repository);

      expect(result.getRight().toNullable(), isEmpty);
    });

    test('401 maps to SpaceUnauthorizedFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 401, body: {'detail': 'no token'}),
      );

      final result = await _getUserSpaces(repository);

      expect(result.getLeft().toNullable(), isA<SpaceUnauthorizedFailure>());
    });

    test('403 maps to SpaceForbiddenFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 403, body: {'detail': 'wrong role'}),
      );

      final result = await _getUserSpaces(repository);

      expect(result.getLeft().toNullable(), isA<SpaceForbiddenFailure>());
    });

    test('500 maps to SpaceServerFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 500, body: {'detail': 'boom'}),
      );

      final result = await _getUserSpaces(repository);

      expect(result.getLeft().toNullable(), isA<SpaceServerFailure>());
    });

    test('connection error maps to SpaceNetworkFailure', () async {
      final repository = _buildRepository(_ConnectionErrorAdapter());

      final result = await _getUserSpaces(repository);

      expect(result.getLeft().toNullable(), isA<SpaceNetworkFailure>());
    });
  });
}
