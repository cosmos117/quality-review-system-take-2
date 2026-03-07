import '../config/api_config.dart';
import 'http_client.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class StageService {
  final SimpleHttp http;
  StageService(this.http);

  void _ensureToken() {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      if (auth.currentUser.value != null &&
          auth.currentUser.value!.token.isNotEmpty) {
        http.accessToken = auth.currentUser.value!.token;
      }
    }
  }

  Future<List<Map<String, dynamic>>> listStages(String projectId) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages',
    );
    final json = await http.getJson(uri);

    final data = (json['data'] as List?) ?? [];

    // Convert to proper Map and ensure counter fields exist
    final stages = data.map((item) {
      final stage = Map<String, dynamic>.from(item as Map);


      // Ensure counters exist with default 0
      stage['loopback_count'] = stage['loopback_count'] ?? 0;
      stage['conflict_count'] = stage['conflict_count'] ?? 0;


      return stage;
    }).toList();

    return stages;
  }

  Future<Map<String, dynamic>> createStage(
    String projectId, {
    required String name,
    String? description,
    String status = 'pending',
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages',
    );
    final body = {
      'stage_name': name,
      if (description != null) 'description': description,
      'status': status,
    };
    final json = await http.postJson(uri, body);
    return (json['data'] as Map<String, dynamic>);
  }

  /// Fetch a single stage by ID
  Future<Map<String, dynamic>> getStageById(String stageId) async {
    _ensureToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/stages/$stageId');
    final response = await http.getJson(uri);
    return response['data'] as Map<String, dynamic>? ?? response;
  }
}