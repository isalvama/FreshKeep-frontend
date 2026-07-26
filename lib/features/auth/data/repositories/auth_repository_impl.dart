import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_request_model.dart';
import '../models/auth_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<AuthFailure, User>> register(String email, String password) {
    return _authenticate(
      () => remoteDataSource.register(
        AuthRequestModel(email: email, password: password),
      ),
    );
  }

  @override
  Future<Either<AuthFailure, User>> login(String email, String password) {
    return _authenticate(
      () => remoteDataSource.login(
        AuthRequestModel(email: email, password: password),
      ),
    );
  }

  Future<Either<AuthFailure, User>> _authenticate(
    Future<AuthResponseModel> Function() call,
  ) async {
    try {
      final response = await call();
      final user = response.toUserModel();
      await localDataSource.saveSession(
        jwt: response.jwtString,
        userId: user.id,
        email: user.email,
      );
      return Right(user);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    }
  }

  AuthFailure _mapDioException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] as String? : null;

    switch (status) {
      case 400:
        return ValidationFailure(detail ?? 'Please check the entered data.');
      case 401:
        return const InvalidCredentialsFailure('Invalid email or password');
      case 403:
        return AccountDisabledFailure(
          detail ?? 'This account has been disabled.',
        );
      case 409:
        return ConflictFailure(detail ?? 'User already exists.');
      case 500:
        return ServerFailure(detail ?? 'Something went wrong. Please try again.');
      default:
        return NetworkFailure(
          e.message ?? 'Network error. Please check your connection.',
        );
    }
  }

  @override
  Future<void> logout() {
    return localDataSource.clearSession();
  }

  @override
  Future<bool> hasValidSession() async {
    final token = await localDataSource.getToken();
    if (token == null) return false;
    if (JwtDecoder.isExpired(token)) {
      await localDataSource.clearSession();
      return false;
    }
    return true;
  }

  @override
  Future<User?> currentUser() async {
    if (!await hasValidSession()) return null;
    return localDataSource.getUser();
  }
}
