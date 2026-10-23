class AuthUser {
  const AuthUser({required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final String name = (json['name'] as String?)?.trim() ?? '';
    final String email = (json['email'] as String?)?.trim() ?? '';

    return AuthUser(
      name: name.isEmpty ? 'Learner' : name,
      email: email,
    );
  }

  final String name;
  final String email;

  Map<String, dynamic> toJson() {
    return {'name': name, 'email': email};
  }
}
