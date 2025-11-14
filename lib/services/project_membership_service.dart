import 'dart:async';
import '../config/api_config.dart';
import '../models/project_membership.dart';
import 'http_client.dart';

class ProjectMembershipService {
  final SimpleHttp http;

  ProjectMembershipService(this.http);

  ProjectMembership _fromApi(Map<String, dynamic> json) {
    return ProjectMembership.fromJson(json);
  }

  Map<String, dynamic> _toApi(ProjectMembership membership) {
    return membership.toJson();
  }

  /// Get all members for a specific project
  /// Backend expects: { "project_id": "..." } in request body
  Future<List<ProjectMembership>> getProjectMembers(String projectId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/members');
    final json = await http.postJson(uri, {'project_id': projectId});

    if (json['data'] is Map && json['data']['members'] is List) {
      final members = (json['data']['members'] as List).cast<dynamic>();
      return members.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Add a member to a project
  /// Backend expects: { "project_id": "...", "user_id": "...", "role_id": "..." }
  Future<ProjectMembership> addMember({
    required String projectId,
    required String userId,
    required String roleId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/members');
    final json = await http.postJson(uri, {
      'project_id': projectId,
      'user_id': userId,
      'role_id': roleId,
    });
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  /// Update a member's role in a project
  /// Backend expects: { "project_id": "...", "user_id": "...", "role_id": "..." }
  Future<ProjectMembership> updateMemberRole({
    required String projectId,
    required String userId,
    required String roleId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/members');
    final json = await http.putJson(uri, {
      'project_id': projectId,
      'user_id': userId,
      'role_id': roleId,
    });
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  /// Remove a member from a project
  /// Backend expects: { "project_id": "...", "user_id": "..." }
  Future<void> removeMember({
    required String projectId,
    required String userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/members');
    await http.deleteJson(uri, {'project_id': projectId, 'user_id': userId});
  }

  /// Get all projects for a specific user
  Future<List<Map<String, dynamic>>> getUserProjects(String userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/$userId/projects');
    final json = await http.getJson(uri);

    if (json['data'] is Map && json['data']['projects'] is List) {
      return (json['data']['projects'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
