import '../config/api_config.dart';
import 'http_client.dart';

class ApprovalService {
  final SimpleHttp http;
  ApprovalService(this.http);

  Future<Map<String, dynamic>> compare(String projectId, int phase) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/approval/compare?phase=$phase',
    );
    final json = await http.getJson(uri);
    return (json['data'] as Map<String, dynamic>)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> request(String projectId, int phase, {String? notes}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/approval/request',
    );
    final json = await http.postJson(uri, {
      'phase': phase,
      if (notes != null) 'notes': notes,
    });
    return (json['data'] as Map<String, dynamic>)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> approve(String projectId, int phase) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/approval/approve',
    );
    final json = await http.postJson(uri, {
      'phase': phase,
    });
    return (json['data'] as Map<String, dynamic>)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> revert(String projectId, int phase, {String? notes}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/approval/revert',
    );
    final json = await http.postJson(uri, {
      'phase': phase,
      if (notes != null) 'notes': notes,
    });
    return (json['data'] as Map<String, dynamic>)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> getStatus(String projectId, int phase) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/approval/status?phase=$phase',
    );
    final json = await http.getJson(uri);
    return (json['data'] as Map<String, dynamic>?)?.cast<String, dynamic>();
  }
}
