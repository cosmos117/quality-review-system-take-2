import 'dart:async';
import '../config/api_config.dart';
import 'http_client.dart';

class DefectCategorizationService {
  final SimpleHttp http;

  DefectCategorizationService(this.http);

  /// Suggest a defect category based on remark text
  /// Returns: { suggestedCategoryId, categoryName, confidence, autoFill, ... }
  Future<Map<String, dynamic>> suggestCategory(
    String checkpointId,
    String remark,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/checkpoints/$checkpointId/suggest-category',
    );
    try {
      final json = await http.postJson(uri, {'remark': remark});
      final data = json['data'] as Map<String, dynamic>?;

      if (data == null) {
        return {
          'suggestedCategoryId': null,
          'confidence': 0,
          'autoFill': false,
        };
      }

      return {
        'suggestedCategoryId': data['suggestedCategoryId'],
        'categoryName': data['categoryName'],
        'confidence': data['confidence'] ?? 0,
        'autoFill': data['autoFill'] ?? false,
        'matchCount': data['matchCount'] ?? 0,
        'tokenCount': data['tokenCount'] ?? 0,
      };
    } catch (e, _) {
      // Return empty suggestion on error (fail gracefully)
      return {
        'suggestedCategoryId': null,
        'confidence': 0,
        'autoFill': false,
        'error': e.toString(),
      };
    }
  }
}
