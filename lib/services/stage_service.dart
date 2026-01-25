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
    print('📍 API Call: GET $uri');
    final json = await http.getJson(uri);
    print('📦 Response: $json');
    final data = (json['data'] as List?) ?? [];
    print('✓ Stages parsed: ${data.length} items');
    return data.cast<Map<String, dynamic>>();
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

  /// Increment loopback counter for a stage (when SDH reverts phase)
  Future<Map<String, dynamic>> incrementLoopbackCounter(String stageId) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/stages/$stageId/increment-loopback',
    );
    print('📍 API Call: PATCH $uri');
    final json = await http.patchJson(uri, {});
    print('📦 Response: $json');
    return (json['data'] as Map<String, dynamic>?) ?? {};
  }
}
