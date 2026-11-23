import '../config/api_config.dart';
import 'api_cache.dart';
import 'http_client.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class StageService {
  final SimpleHttp http;
  final ApiCache _cache = ApiCache(defaultTtl: const Duration(minutes: 2));

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

  Future<List<Map<String, dynamic>>> listStages(
    String projectId, {
    bool forceRefresh = false,
  }) async {
    return _cache.get('stages:$projectId', () async {
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
    }, forceRefresh: forceRefresh);
  }

  void clearCache() => _cache.clear();
}
