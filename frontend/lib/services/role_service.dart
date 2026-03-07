import '../config/api_config.dart';
import '../models/role.dart';
import 'http_client.dart';

class RoleService {
  final SimpleHttp http;

  RoleService(this.http);

  Role _fromApi(Map<String, dynamic> json) {
    return Role.fromJson(json);
  }

  Map<String, dynamic> _toApi(Role role) {
    return role.toJson();
  }

  Future<List<Role>> getAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<Role> getById(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles/$id');
    final json = await http.getJson(uri);
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<Role> create(Role role) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles');
    final json = await http.postJson(uri, _toApi(role));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<Role> update(Role role) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles/${role.id}');
    final json = await http.putJson(uri, _toApi(role));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/roles/$id');
    await http.delete(uri);
  }
}
