import 'user_model.dart';

class RegisterResponseModel {
  final String accountId;
  final String email;

  const RegisterResponseModel({required this.accountId, required this.email});

  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterResponseModel(
      accountId: json['accountId'] as String,
      email: json['email'] as String,
    );
  }

  UserModel toUserModel() => UserModel(id: accountId, email: email);
}
