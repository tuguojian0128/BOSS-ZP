class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.user});
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
}

abstract class AuthRepository {
  Future<AuthSession> login({required String identifier, required String password});
  Future<AuthSession> register({required String identifier, required String password, required String displayName});
  Future<void> logout();
}
