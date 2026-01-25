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

  /// Get all members for a specific project
  /// Backend expects: { "project_id": "..." } in request body
  Future<List<ProjectMembership>> getProjectMembers(String projectId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/projects/members?project_id=$projectId',
      );
      // ignore: avoid_print
      print(
        '[ProjectMembershipService] getProjectMembers -> GET $uri',
      );
      final json = await http.getJson(uri);
      // ignore: avoid_print
      print(
        '[ProjectMembershipService] getProjectMembers <- response keys=${json.keys.join(', ')}',
      );
      if (json['error'] != null) {
        // ignore: avoid_print
        print(
          '[ProjectMembershipService] getProjectMembers ERROR: ${json['error']}',
        );
      }

      if (json['data'] is Map && json['data']['members'] is List) {
        final members = (json['data']['members'] as List).cast<dynamic>();
        // ignore: avoid_print
        print(
          '[ProjectMembershipService] getProjectMembers parsed members count=${members.length}',
        );
        return members.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
      }
      // ignore: avoid_print
      print(
        '[ProjectMembershipService] getProjectMembers parsed members count=0 (no data.members list)',
      );
      return [];
    } catch (e) {
      // ignore: avoid_print
      print(
        '[ProjectMembershipService] getProjectMembers failed for project=$projectId: $e',
      );
      // If fetching existing members fails (e.g., orphaned user references),
      // return empty list so we can still add new valid members
      return [];
    }
  }

  /// Add a member to a project
  /// Backend expects: { "project_id": "...", "user_id": "...", "role_id": "..." }
  Future<ProjectMembership> addMember({
    required String projectId,
    required String userId,
    required String roleId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/members');
    // Debug logging to help trace membership creation issues (e.g. User not found)
    // Remove or silence if too noisy after resolving the issue.
    // Prints the payload being sent to backend.
    // Note: Keeping this lightweight; no additional error handling here.
    // ignore: avoid_print
    print(
      '[ProjectMembershipService] addMember -> project_id=$projectId user_id=$userId role_id=$roleId',
    );
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
    // ignore: avoid_print
    print(
      '[ProjectMembershipService] removeMember -> project_id=$projectId user_id=$userId',
    );
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
