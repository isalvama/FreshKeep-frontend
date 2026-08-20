import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({required super.id, required super.email});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['accountId'] as String,
      email: json['email'] as String,
    );
  }
}
