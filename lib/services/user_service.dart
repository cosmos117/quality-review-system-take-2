import 'dart:async';
import '../config/api_config.dart';
import '../models/team_member.dart';
import 'http_client.dart';

class UserService {
  final SimpleHttp http;
  Timer? _pollTimer;
  final _usersController = StreamController<List<TeamMember>>.broadcast();

  UserService(this.http);

  TeamMember _fromApi(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id']).toString();
    final name = (j['name'] ?? j['fullName'] ?? '').toString();
    final email = (j['email'] ?? '').toString();
    // Backend role is either 'user' or 'admin'
    final roleRaw = (j['role'] ?? '').toString().toLowerCase();
    final role = roleRaw == 'admin' ? 'Admin' : 'User';
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

  Future<List<TeamMember>> getAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<TeamMember> create(TeamMember m) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/register');
    final json = await http.postJson(uri, _toApi(m));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<TeamMember> update(TeamMember m) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/${m.id}');
    final json = await http.putJson(uri, _toApi(m));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$id');
    await http.delete(uri);
  }

  Stream<List<TeamMember>> getUsersStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final users = await getAll();
        if (!_usersController.isClosed) {
          _usersController.add(users);
        }
      } catch (e) {
        if (!_usersController.isClosed) {
          _usersController.addError(e);
        }
      }
    });
    // Immediately fetch initial data
    getAll()
        .then((users) {
          if (!_usersController.isClosed) {
            _usersController.add(users);
          }
        })
        .catchError((e) {
          if (!_usersController.isClosed) {
            _usersController.addError(e);
          }
        });
    return _usersController.stream;
  }

  void dispose() {
    _pollTimer?.cancel();
    _usersController.close();
  }
}
