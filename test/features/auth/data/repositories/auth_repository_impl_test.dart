import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/core/errors/failures.dart';
import 'package:fresh_keep_frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:fresh_keep_frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fresh_keep_frontend/features/auth/data/repositories/auth_repository_impl.dart';

class _JsonResponseAdapter implements HttpClientAdapter {
  _JsonResponseAdapter({required this.statusCode, this.body});

  final int statusCode;
  final Map<String, dynamic>? body;

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

class _SpyAuthLocalDataSource extends AuthLocalDataSource {
  _SpyAuthLocalDataSource() : super(const FlutterSecureStorage());

  bool saveSessionCalled = false;

  @override
  Future<void> saveSession({
    required String jwt,
    required String userId,
    required String email,
  }) async {
    saveSessionCalled = true;
  }

  @override
  Future<String?> getToken() async => null;
}

AuthRepositoryImpl _buildRepository(
  HttpClientAdapter adapter, {
  AuthLocalDataSource? localDataSource,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSource(dio),
    localDataSource:
        localDataSource ?? const AuthLocalDataSource(FlutterSecureStorage()),
  );
}

void main() {
  group('AuthRepositoryImpl status-code-to-failure mapping', () {
    test('400 maps to ValidationFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 400, body: {'detail': 'bad input'}),
      );

      final result = await repository.login('user@example.com', 'password1');

      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    });

    test('401 maps to InvalidCredentialsFailure with a generic message', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 401, body: {'detail': 'wrong password'}),
      );

      final result = await repository.login('user@example.com', 'password1');

      final failure = result.getLeft().toNullable();
      expect(failure, isA<InvalidCredentialsFailure>());
      expect(failure!.message, 'Invalid email or password');
    });

    test('403 maps to AccountDisabledFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 403, body: {'detail': 'disabled'}),
      );

      final result = await repository.login('user@example.com', 'password1');

      expect(result.getLeft().toNullable(), isA<AccountDisabledFailure>());
    });

    test('409 maps to ConflictFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 409, body: {'detail': 'already exists'}),
      );

      final result = await repository.register('user@example.com', 'password1');

      expect(result.getLeft().toNullable(), isA<ConflictFailure>());
    });

    test('500 maps to ServerFailure', () async {
      final repository = _buildRepository(
        _JsonResponseAdapter(statusCode: 500, body: {'detail': 'boom'}),
      );

      final result = await repository.login('user@example.com', 'password1');

      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });

    test('connection error maps to NetworkFailure', () async {
      final repository = _buildRepository(_ConnectionErrorAdapter());

      final result = await repository.login('user@example.com', 'password1');

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.register session handling', () {
    test('a successful registration does not persist a session', () async {
      final localDataSource = _SpyAuthLocalDataSource();
      final repository = _buildRepository(
        _JsonResponseAdapter(
          statusCode: 201,
          body: {'accountId': 'abc-123', 'email': 'user@example.com'},
        ),
        localDataSource: localDataSource,
      );

      final result = await repository.register(
        'user@example.com',
        'password1',
      );

      final user = result.getRight().toNullable();
      expect(user, isNotNull);
      expect(user!.id, 'abc-123');
      expect(user.email, 'user@example.com');
      expect(localDataSource.saveSessionCalled, isFalse);
      expect(await localDataSource.getToken(), isNull);
    });
  });
}
