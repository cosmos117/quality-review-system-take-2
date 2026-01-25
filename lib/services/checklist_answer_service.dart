import 'dart:async';
import '../config/api_config.dart';
import 'http_client.dart';

class ChecklistAnswerService {
  final SimpleHttp http;

  ChecklistAnswerService(this.http);

  /// Get all checklist answers for a specific project, phase, and role
  /// Returns a map: { "sub_question": { "answer": "Yes", "remark": "...", "images": [...], ... } }
  Future<Map<String, Map<String, dynamic>>> getAnswers(
    String projectId,
    int phase,
    String role,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/checklist-answers?phase=$phase&role=${role.toLowerCase()}',
    );
    try {
      final json = await http.getJson(uri);
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        return {};
      }

      // Convert to proper structure
      final result = <String, Map<String, dynamic>>{};
      data.forEach((key, value) {
        if (value is Map) {
          result[key] = Map<String, dynamic>.from(value);
        }
      });
      return result;
    } catch (e, _) {
      return {};
    }
  }

  /// Save/update checklist answers
  /// answers: { "sub_question": { "answer": "Yes", "remark": "...", "images": [...] }, ... }
  Future<bool> saveAnswers(
    String projectId,
    int phase,
    String role,
    Map<String, Map<String, dynamic>> answers,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/checklist-answers',
    );

    final body = {
      'phase': phase,
      'role': role.toLowerCase(),
      'answers': answers,
    };
    answers.forEach((question, data) {});

    try {
      await http.putJson(uri, body);
      return true;
    } catch (e, _) {
      return false;
    }
  }

  /// Submit checklist (mark all answers as submitted)
  Future<bool> submitChecklist(String projectId, int phase, String role) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/checklist-answers/submit',
    );

    final body = {'phase': phase, 'role': role.toLowerCase()};

    try {
      await http.postJson(uri, body);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get submission status
  /// Returns: { "is_submitted": bool, "answer_count": int, "submitted_at": DateTime? }
  Future<Map<String, dynamic>> getSubmissionStatus(
    String projectId,
    int phase,
    String role,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/projects/$projectId/checklist-answers/submission-status?phase=$phase&role=${role.toLowerCase()}',
    );

    try {
      final json = await http.getJson(uri);
      final data = json['data'] as Map<String, dynamic>?;

      if (data == null) {
        return {'is_submitted': false, 'answer_count': 0, 'submitted_at': null};
      }

      return {
        'is_submitted': data['is_submitted'] ?? false,
        'answer_count': data['answer_count'] ?? 0,
        'submitted_at': data['submitted_at'] != null
            ? DateTime.tryParse(data['submitted_at'].toString())
            : null,
      };
    } catch (e) {
      return {'is_submitted': false, 'answer_count': 0, 'submitted_at': null};
    }
  }
}
