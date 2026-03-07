import '../config/api_config.dart';
import '../models/team_member.dart';
import 'api_cache.dart';
import 'http_client.dart';

class UserService {
  final SimpleHttp http;
  final ApiCache _cache = ApiCache(defaultTtl: const Duration(minutes: 2));

  UserService(this.http);

  TeamMember _fromApi(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id']).toString();
    final name = (j['name'] ?? j['fullName'] ?? '').toString();
    final email = (j['email'] ?? '').toString();
    // Backend role is either 'user' or 'admin'
    final roleRaw = (j['role'] ?? '').toString().toLowerCase();
    final role = roleRaw == 'admin' ? 'Admin' : 'Employee';
    final createdAt = (j['createdAt'] ?? j['dateAdded'] ?? '').toString();
    final updatedAt = (j['updatedAt'] ?? j['lastActive'] ?? '').toString();
    return TeamMember(
      id: id,
      name: name.isEmpty ? 'Unnamed' : name,
      email: email,
      role: role,
      status: 'Active', // Backend doesn't have status field yet
      dateAdded: createdAt,
      lastActive: updatedAt.isEmpty ? createdAt : updatedAt,
    );
  }

  Map<String, dynamic> _toApi(TeamMember m) {
    return {
      'name': m.name,
      'email': m.email,
      'role': m.role.toLowerCase() == 'admin' ? 'admin' : 'user',
      if (m.password != null && m.password!.isNotEmpty) 'password': m.password,
    };
  }

  Future<List<TeamMember>> getAll({bool forceRefresh = false}) async {
    return _cache.get('all', () async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/users');
      final json = await http.getJson(uri);
      final data = (json['data'] as List).cast<dynamic>();
      return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
    }, forceRefresh: forceRefresh);
  }

  Future<TeamMember> create(TeamMember m) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/register');
    final json = await http.postJson(uri, _toApi(m));
    _cache.clear();
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<TeamMember> update(TeamMember m) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/${m.id}');
    final json = await http.putJson(uri, _toApi(m));
    _cache.clear();
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$id');
    await http.delete(uri);
    _cache.clear();
  }

  void clearCache() => _cache.clear();
}
