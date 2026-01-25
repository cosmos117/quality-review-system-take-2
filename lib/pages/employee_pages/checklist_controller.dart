import 'package:get/get.dart';
import '../../services/http_client.dart';
import '../../services/checklist_answer_service.dart';
import '../../services/approval_service.dart';

class ChecklistController extends GetxService {
  late final ChecklistAnswerService _answerService;
  late final ApprovalService _approvalService;

  // Cache for loaded answers: projectId -> phase -> role -> subQuestion -> answer map
  final _cache = <String, Map<int, Map<String, Map<String, dynamic>>>>{}.obs;

  // Submission status cache: projectId -> phase -> role -> metadata
  final _submissionCache = <String, Map<int, Map<String, dynamic>>>{}.obs;

  // Loading state
  final _isLoading = <String, bool>{}.obs;

  // Pending saves (debouncing)
  final Map<String, Future<void>> _pendingSaves = {};

  // Removed stage/checklist caches - using direct checklist answers endpoints

  @override
  void onInit() {
    super.onInit();    // Initialize service
    try {
      final http = Get.find<SimpleHttp>();
  _answerService = ChecklistAnswerService(http);
  _approvalService = Get.find<ApprovalService>();    } catch (e) {      rethrow;
    }
  }

  /// Load answers from backend for a specific project/phase/role
  Future<void> loadAnswers(String projectId, int phase, String role) async {    final key = '$projectId-$phase-$role';
    if (_isLoading[key] == true) {      return; // Already loading
    }

    _isLoading[key] = true;    try {
  // Direct load from checklist-answer API
  final answers = await _answerService.getAnswers(projectId, phase, role);      // Store in cache
      final proj = _cache.putIfAbsent(projectId, () => {});
      final phaseMap = proj.putIfAbsent(phase, () => {});
      phaseMap[role] = answers;
      _cache.refresh();

      // Also load submission status
      await _loadSubmissionStatus(projectId, phase, role);
    } catch (e) {    } finally {
      _isLoading[key] = false;
    }
  }

  // Removed stage/checklist creation logic

  /// Get a specific answer from cache
  Map<String, dynamic>? getAnswers(
    String projectId,
    int phase,
    String role,
    String subQ,
  ) {
    return _cache[projectId]?[phase]?[role]?[subQ];
  }

  /// Get all answers for a role (entire role sheet)
  Map<String, Map<String, dynamic>> getRoleSheet(
    String projectId,
    int phase,
    String role,
  ) {
    return Map<String, Map<String, dynamic>>.from(
      _cache[projectId]?[phase]?[role] ?? {},
    );
  }

  /// Set/update a single answer and save to backend
  Future<void> setAnswer(
    String projectId,
    int phase,
    String role,
    String subQ,
    Map<String, dynamic> ans,
  ) async {
    // Update cache immediately for responsive UI
    final proj = _cache.putIfAbsent(projectId, () => {});
    final phaseMap = proj.putIfAbsent(phase, () => {});
    final roleMap = phaseMap.putIfAbsent(role, () => {});
    roleMap[subQ] = ans;
    _cache.refresh();

    // Debounce save to backend (wait for user to finish typing)
    final saveKey = '$projectId-$phase-$role';
    _pendingSaves[saveKey]?.ignore(); // Cancel pending save if exists

    _pendingSaves[saveKey] = Future.delayed(
      const Duration(milliseconds: 500),
      () => _saveToBackend(projectId, phase, role),
    );
  }

  /// Save all answers for a role to backend
  Future<bool> _saveToBackend(String projectId, int phase, String role) async {
    try {
  final answers = getRoleSheet(projectId, phase, role);      final ok = await _answerService.saveAnswers(projectId, phase, role, answers);
      if (ok) {        // Editing clears submission status; update cache so UI enables resubmit
        final proj = _submissionCache.putIfAbsent(projectId, () => {});
        final phaseMap = proj.putIfAbsent(phase, () => {});
        phaseMap[role] = {
          'is_submitted': false,
          'submitted_at': null,
          'answer_count': answers.length,
        };
        _submissionCache.refresh();
      }
      return true;
    } catch (e) {      return false;
    }
  }

  /// Submit checklist (mark as submitted on backend)
  Future<bool> submitChecklist(String projectId, int phase, String role) async {
    try {
      // First ensure all answers are saved
      await _saveToBackend(projectId, phase, role);

  // Submit via checklist-answer API
  final success = await _answerService.submitChecklist(projectId, phase, role);

      if (success) {
        // Update submission cache
        final proj = _submissionCache.putIfAbsent(projectId, () => {});
        final phaseMap = proj.putIfAbsent(phase, () => {});
        phaseMap[role] = {
          'is_submitted': true,
          'submitted_at': DateTime.now(),
          'answer_count': getRoleSheet(projectId, phase, role).length,
        };
        _submissionCache.refresh();  // If both roles are submitted and answers match, auto request SDH approval
  await _maybeRequestApproval(projectId, phase);
      }

      return success;
    } catch (e) {      return false;
    }
  }

  // If executor and reviewer are both submitted and their answers match, request approval
  Future<void> _maybeRequestApproval(String projectId, int phase) async {
    try {
      // Ensure we have fresh submission status for both roles
      final execStatus = await _answerService.getSubmissionStatus(projectId, phase, 'executor');
      final revStatus = await _answerService.getSubmissionStatus(projectId, phase, 'reviewer');

      final execSubmitted = execStatus['is_submitted'] == true;
      final revSubmitted = revStatus['is_submitted'] == true;
      if (!execSubmitted || !revSubmitted) {        return;
      }

      // Compare answers on backend
      final cmp = await _approvalService.compare(projectId, phase);
      if (cmp['match'] == true) {
        await _approvalService.request(projectId, phase);      } else {
      }
    } catch (e) {    }
  }

  /// Get submission info from cache
  Map<String, dynamic>? submissionInfo(
    String projectId,
    int phase,
    String role,
  ) {
    return _submissionCache[projectId]?[phase]?[role];
  }

  /// Load submission status from backend
  Future<void> _loadSubmissionStatus(
    String projectId,
    int phase,
    String role,
  ) async {
    try {
      // Derive status locally from checklist since dedicated service removed
      final status = await _deriveSubmissionStatus(projectId, phase, role);
      final proj = _submissionCache.putIfAbsent(projectId, () => {});
      final phaseMap = proj.putIfAbsent(phase, () => {});
      phaseMap[role] = status;
      _submissionCache.refresh();
    } catch (e) {    }
  }

  /// Derive submission status from existing checklist data
  Future<Map<String, dynamic>> _deriveSubmissionStatus(
    String projectId,
    int phase,
    String role,
  ) async {
    try {
      final status = await _answerService.getSubmissionStatus(projectId, phase, role);
      return status;
    } catch (e) {      return {
        'is_submitted': false,
        'submitted_at': null,
        'answer_count': 0,
      };
    }
  }

  /// Check if currently loading
  bool isLoading(String projectId, int phase, String role) {
    return _isLoading['$projectId-$phase-$role'] ?? false;
  }

  /// Clear cache for a specific project to force reload from backend
  void clearProjectCache(String projectId) {    _cache.remove(projectId);
    _submissionCache.remove(projectId);
    _cache.refresh();
    _submissionCache.refresh();
  }

  /// Clear all cache
  void clearAllCache() {    _cache.clear();
    _submissionCache.clear();
    _cache.refresh();
    _submissionCache.refresh();
  }
}
