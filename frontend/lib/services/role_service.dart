import '../config/api_config.dart';
import '../models/role.dart';
import 'api_cache.dart';
import 'http_client.dart';

class RoleService {
  final SimpleHttp http;
  final ApiCache _cache = ApiCache(defaultTtl: const Duration(minutes: 5));

  RoleService(this.http);

  Role _fromApi(Map<String, dynamic> json) {
    return Role.fromJson(json);
  }

  Map<String, dynamic> _toApi(Role role) {
    return role.toJson();
  }

  Future<List<Role>> getAll({bool forceRefresh = false}) async {
    return _cache.get('all', () async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/roles');
      final json = await http.getJson(uri);
      final data = (json['data'] as List).cast<dynamic>();
      return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
    }, forceRefresh: forceRefresh);
  }

  Future<Role> getById(String id, {bool forceRefresh = false}) async {
    return _cache.get('id:$id', () async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/roles/$id');
      final json = await http.getJson(uri);
      return _fromApi(json['data'] as Map<String, dynamic>);
    }, forceRefresh: forceRefresh);
  }

  Future<Role> create(Role role) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles');
    final json = await http.postJson(uri, _toApi(role));
    _cache.clear();
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<Role> update(Role role) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles/${role.id}');
    final json = await http.putJson(uri, _toApi(role));
    _cache.clear();
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles/$id');
    await http.delete(uri);
    _cache.clear();
  }

  void clearCache() => _cache.clear();
}
