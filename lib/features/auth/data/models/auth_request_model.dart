class AuthRequestModel {
  final String email;
  final String password;

  const AuthRequestModel({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}
