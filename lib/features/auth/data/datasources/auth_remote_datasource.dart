import 'package:dio/dio.dart';

import '../models/auth_request_model.dart';
import '../models/auth_response_model.dart';
import '../models/register_response_model.dart';

class AuthRemoteDataSource {
  final Dio dio;

  const AuthRemoteDataSource(this.dio);

  Future<RegisterResponseModel> register(AuthRequestModel request) async {
    final response = await dio.post(
      '/api/v1/auth/register/user',
      data: request.toJson(),
    );
    return RegisterResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<AuthResponseModel> login(AuthRequestModel request) async {
    final response = await dio.post(
      '/api/v1/auth/login',
      data: request.toJson(),
    );
    return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
  }
}
