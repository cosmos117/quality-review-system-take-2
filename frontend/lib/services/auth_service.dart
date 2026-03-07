import '../config/api_config.dart';
import '../models/auth_user.dart';
import 'http_client.dart';

class AuthService {
  final SimpleHttp http;

  AuthService(this.http);

  Future<AuthUser> login(String email, String password) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/login');
    final body = await http.postJson(uri, {
      'email': email,
      'password': password,
    });

    // Extract token from response body (backend now includes it)
    final data = (body is Map && body['data'] is Map)
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    String token = data['token']?.toString() ?? '';

    return AuthUser.fromJson(data, token: token);
  }

  Future<void> logout(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/logout');
    try {
      // Temporarily set token for this request
      final previousToken = http.accessToken;
      http.accessToken = token;
      await http.postJson(uri, {});
      http.accessToken = previousToken;
    } catch (_) {
      // Best-effort: even if the server call fails, we still clear local state
    }
  }
}
