import 'package:get/get.dart';
import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import 'api_cache.dart';
import 'http_client.dart';

class ProjectChecklistService {
  final SimpleHttp http;
  final ApiCache _cache = ApiCache(defaultTtl: const Duration(minutes: 1));

  ProjectChecklistService(this.http);

  void _ensureToken() {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      final user = auth.currentUser.value;
      if (user != null && user.token.isNotEmpty) {
        http.accessToken = user.token;
      }
    }
  }

  Future<Map<String, dynamic>> fetchChecklist(
    String projectId,
    String stageId, {
    bool forceRefresh = false,
  }) async {
    return _cache.get('checklist:$projectId:$stageId', () async {
      _ensureToken();
      final uri = Uri.parse(
        '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages/$stageId/project-checklist',
      );
      final json = await http.getJson(uri);
      return (json['data'] as Map<String, dynamic>? ?? {});
    }, forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> updateExecutor(
    String projectId,
    String stageId,
    String groupId,
    String questionId, {
    required String? answer,
    String? remark,
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages/$stageId/checklist/groups/$groupId/questions/$questionId/executor',
    );
    final payload = {'answer': answer, if (remark != null) 'remark': remark};
    final json = await http.patchJson(uri, payload);
    _cache.clear();
    return (json['data'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> updateReviewer(
    String projectId,
    String stageId,
    String groupId,
    String questionId, {
    required String? status,
    String? remark,
    String? categoryId,
    String? severity,
  }) async {
    _ensureToken();
    final uri = Uri.parse(
      '${ApiConfig.checklistBaseUrl}/projects/$projectId/stages/$stageId/checklist/groups/$groupId/questions/$questionId/reviewer',
    );
    final payload = {
      'status': status,
      if (remark != null) 'remark': remark,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
    };
    final json = await http.patchJson(uri, payload);
    _cache.clear();
    return (json['data'] as Map<String, dynamic>? ?? {});
  }

  Future<Map<String, dynamic>> getDefectRatesPerIteration(
    String projectId,
    int phase, {
    bool forceRefresh = false,
  }) async {
    return _cache.get('defectRates:$projectId:$phase', () async {
      _ensureToken();
      final uri = Uri.parse(
        '${ApiConfig.checklistBaseUrl}/projects/$projectId/defect-rates?phase=$phase',
      );
      final json = await http.getJson(uri);
      return (json['data'] as Map<String, dynamic>? ?? {});
    }, forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> getOverallDefectRate(
    String projectId, {
    bool forceRefresh = false,
  }) async {
    return _cache.get('overallDefect:$projectId', () async {
      _ensureToken();
      final uri = Uri.parse(
        '${ApiConfig.checklistBaseUrl}/projects/$projectId/overall-defect-rate',
      );
      final json = await http.getJson(uri);
      return (json['data'] as Map<String, dynamic>? ?? {});
    }, forceRefresh: forceRefresh);
  }

  void clearCache() => _cache.clear();
}
