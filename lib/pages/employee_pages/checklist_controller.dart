import 'package:get/get.dart';

class ChecklistController extends GetxService {
  // projectId/title -> role -> subQuestion -> answer map
  final _store = <String, Map<String, Map<String, dynamic>>>{}.obs;
  // projectId/title -> role -> submitted metadata
  final _submitted = <String, Map<String, Map<String, dynamic>>>{}.obs;

  Map<String, dynamic>? getAnswers(String projectKey, String role, String subQ) {
    return _store[projectKey]?[role]?[subQ] as Map<String, dynamic>?;
  }

  Map<String, Map<String, dynamic>> getRoleSheet(String projectKey, String role) {
    return Map<String, Map<String, dynamic>>.from(_store[projectKey]?[role] ?? {});
  }

  void setAnswer(String projectKey, String role, String subQ, Map<String, dynamic> ans) {
    final proj = _store.putIfAbsent(projectKey, () => {});
    final roleMap = proj.putIfAbsent(role, () => {});
    roleMap[subQ] = ans;
    _store.refresh();
  }

  void submitChecklist(String projectKey, String role) {
    final projAnswers = _store[projectKey]?[role] ?? {};
    final meta = {
      'submitted': true,
      'submittedAt': DateTime.now().toIso8601String(),
      'count': projAnswers.length,
    };
    final proj = _submitted.putIfAbsent(projectKey, () => {});
    proj[role] = meta;
    _submitted.refresh();
  }

  Map<String, dynamic>? submissionInfo(String projectKey, String role) {
    return _submitted[projectKey]?[role];
  }
}