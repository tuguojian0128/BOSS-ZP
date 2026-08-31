import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';

class RestAuthRepository implements AuthRepository {
  RestAuthRepository(this.api);
  final ApiClient api;

  @override
  Future<AuthSession> login({required String identifier, required String password}) async {
    final result = await api.postJson('/api/v1/auth/login', {
      if (identifier.contains('@')) 'email': identifier else 'phone': identifier,
      'password': password,
    });
    return _session(result);
  }

  @override
  Future<AuthSession> register({required String identifier, required String password, required String displayName}) async {
    final result = await api.postJson('/api/v1/auth/register', {
      if (identifier.contains('@')) 'email': identifier else 'phone': identifier,
      'password': password,
      'displayName': displayName,
    });
    return _session(result);
  }

  @override
  Future<void> logout() async {
    try {
      await api.postJson('/api/v1/auth/logout', {
        if (api.refreshToken != null) 'refreshToken': api.refreshToken,
      });
    } finally {
      api.accessToken = null;
      api.refreshToken = null;
      ApiClient.clearSharedTokens();
    }
  }

  AuthSession _session(Map<String, dynamic> result) {
    final session = AuthSession(
      accessToken: result['accessToken'].toString(),
      refreshToken: result['refreshToken'].toString(),
      user: Map<String, dynamic>.from(result['user'] as Map),
    );
    api.accessToken = session.accessToken;
    api.refreshToken = session.refreshToken;
    ApiClient.setSharedTokens(accessToken: session.accessToken, refreshToken: session.refreshToken);
    return session;
  }
}
