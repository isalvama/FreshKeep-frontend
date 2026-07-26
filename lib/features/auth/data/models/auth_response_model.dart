import 'user_model.dart';

class AuthResponseModel {
  final String accountId;
  final String email;
  final String jwtString;
  final int expiresIn; // raw jwt.expiration config value in ms — not a countdown, not used for expiry checks

  const AuthResponseModel({
    required this.accountId,
    required this.email,
    required this.jwtString,
    required this.expiresIn,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accountId: json['accountId'] as String,
      email: json['email'] as String,
      jwtString: json['jwtString'] as String,
      expiresIn: json['expiresIn'] as int,
    );
  }

  UserModel toUserModel() => UserModel(id: accountId, email: email);
}
