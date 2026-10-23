import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/storage_keys.dart';
import '../models/user_model.dart';

class AuthLocalDataSource {
  final FlutterSecureStorage secureStorage;

  const AuthLocalDataSource(this.secureStorage);

  Future<void> saveSession({
    required String jwt,
    required String userId,
    required String email,
  }) async {
    await secureStorage.write(key: StorageKeys.authJwtToken, value: jwt);
    await secureStorage.write(key: StorageKeys.authUserId, value: userId);
    await secureStorage.write(key: StorageKeys.authUserEmail, value: email);
  }

  Future<String?> getToken() {
    return secureStorage.read(key: StorageKeys.authJwtToken);
  }

  Future<UserModel?> getUser() async {
    final id = await secureStorage.read(key: StorageKeys.authUserId);
    final email = await secureStorage.read(key: StorageKeys.authUserEmail);
    if (id == null || email == null) return null;
    return UserModel(id: id, email: email);
  }

  Future<void> clearSession() async {
    await secureStorage.delete(key: StorageKeys.authJwtToken);
    await secureStorage.delete(key: StorageKeys.authUserId);
    await secureStorage.delete(key: StorageKeys.authUserEmail);
  }
}
