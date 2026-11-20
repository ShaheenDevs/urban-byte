class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.roles, required this.permissions, required this.name});
  final String accessToken;
  final String refreshToken;
  final List<String> roles;
  final List<String> permissions;
  final String name;
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      roles: (user['roles'] as List<dynamic>? ?? const []).cast<String>(),
      permissions: (user['permissions'] as List<dynamic>? ?? const []).cast<String>(),
      name: user['name'] as String? ?? 'Staff',
    );
  }
}
