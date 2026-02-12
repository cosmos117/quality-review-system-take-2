import 'package:get/get.dart';
import '../models/project.dart';
import '../services/approval_service.dart';
import '../services/stage_service.dart';
import 'auth_controller.dart';

/// Controller to track notification states for projects
class NotificationController extends GetxController {
  ApprovalService get _approvalService => Get.find<ApprovalService>();
  StageService get _stageService => Get.find<StageService>();

  // Map of projectId to notification info
  final _projectNotifications = <String, ProjectNotification>{}.obs;

  // Count of total notifications
  final notificationCount = 0.obs;

  // Count of executor-only (revert) notifications
  final executorNotificationCount = 0.obs;

  /// Check if a project has any pending actions for the current user
  bool hasNotification(String projectId) {
    return _projectNotifications[projectId]?.hasPendingAction ?? false;
  }

  /// Get notification info for a project
  ProjectNotification? getNotification(String projectId) {
    return _projectNotifications[projectId];
  }

  /// Update notification status for a project
  Future<void> updateProjectNotification(Project project) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final userId = authCtrl.currentUser.value?.id;
      final userName = authCtrl.currentUser.value?.name;

      if (userId == null) return;

      final executors = project.assignedEmployees ?? [];
      // Executor: user in assignedEmployees list (who fills checklists)
      final isExecutor = _listMatchesUser(executors, userId, userName);
      // Reviewer: user is competenceManager or executor (who approves/reverts)
      final isReviewer =
          _matchesUser(project.competenceManager, userId, userName) ||
          _matchesUser(project.executor, userId, userName);

      bool hasPendingAction = false;
      String? actionType;
      int? phaseNumber;
      String? stageName;

      // Get stage information to retrieve stage names
      List<Map<String, dynamic>> stages = [];
      try {
        stages = await _stageService.listStages(project.id);
      } catch (e) {
        print('Could not fetch stages for ${project.id}: $e');
      }

      // Check all phases (1 to 7 typically)
      for (int phase = 1; phase <= 7; phase++) {
        try {
          final approval = await _approvalService.getStatus(project.id, phase);

          final status = _normalizeStatus(
            approval?['status'] ??
                approval?['state'] ??
                approval?['approvalStatus'],
          );

          // Executor needs to act if reverted (ONLY for executors, not reviewers)
          if (isExecutor && !isReviewer && _isRevertedStatus(status)) {
            hasPendingAction = true;
            actionType = 'revert';
            phaseNumber = phase;
            stageName = _getStageName(stages, phase);
            break;
          }

          // Reviewer needs to act if submitted by executor
          if (isReviewer && !isExecutor && _isPendingReviewStatus(status)) {
            hasPendingAction = true;
            actionType = 'pending_review';
            phaseNumber = phase;
            stageName = _getStageName(stages, phase);
            break;
          }
        } catch (e) {
          // Phase doesn't exist or error, continue
          continue;
        }
      }

      _projectNotifications[project.id] = ProjectNotification(
        projectId: project.id,
        hasPendingAction: hasPendingAction,
        actionType: actionType,
        phaseNumber: phaseNumber,
        stageName: stageName,
      );

      _updateNotificationCount();
    } catch (e) {
      print('Error updating notification for ${project.id}: $e');
    }
  }

  /// Update notifications for multiple projects
  Future<void> updateMultipleProjects(List<Project> projects) async {
    for (final project in projects) {
      await updateProjectNotification(project);
    }
  }

  /// Clear notification for a project
  void clearProjectNotification(String projectId) {
    _projectNotifications.remove(projectId);
    _updateNotificationCount();
  }

  /// Clear all notifications
  void clearAll() {
    _projectNotifications.clear();
    notificationCount.value = 0;
  }

  void _updateNotificationCount() {
    notificationCount.value = _projectNotifications.values
        .where((n) => n.hasPendingAction)
        .length;
    executorNotificationCount.value = _projectNotifications.values
        .where((n) => n.hasPendingAction && n.actionType == 'revert')
        .length;
  }

  String _normalizeStatus(dynamic raw) {
    if (raw == null) return '';
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty) return '';
    return value.replaceAll(' ', '_').replaceAll('-', '_');
  }

  bool _isRevertedStatus(String status) {
    if (status.isEmpty) return false;
    return status == 'reverted' ||
        status == 'reverted_to_executor' ||
        status == 'revert_to_executor' ||
        status == 'revertedtoexecutor' ||
        status.contains('revert');
  }

  bool _isPendingReviewStatus(String status) {
    if (status.isEmpty) return false;
    return status == 'submitted_for_review' ||
        status == 'pending_review' ||
        status == 'submitted_for_reviewer' ||
        (status.contains('submitted') && status.contains('review'));
  }

  bool _listMatchesUser(List<String> list, String? userId, String? userName) {
    for (final value in list) {
      if (_matchesUser(value, userId, userName)) return true;
    }
    return false;
  }

  bool _matchesUser(String? candidate, String? userId, String? userName) {
    if (candidate == null) return false;
    final normalized = candidate.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (userId != null && normalized == userId.trim().toLowerCase()) {
      return true;
    }
    if (userName != null && normalized == userName.trim().toLowerCase()) {
      return true;
    }
    return false;
  }

  String _getStageName(List<Map<String, dynamic>> stages, int phaseNumber) {
    if (stages.isEmpty) return 'Phase $phaseNumber';

    // Try to find stage by index (phase 1 = index 0)
    final index = phaseNumber - 1;
    if (index >= 0 && index < stages.length) {
      final stageName = stages[index]['stage_name'];
      if (stageName != null && stageName.toString().trim().isNotEmpty) {
        return stageName.toString().trim();
      }
    }

    // Fallback: search by stage_key
    final stageKey = 'stage$phaseNumber';
    try {
      final stage = stages.firstWhere((s) => s['stage_key'] == stageKey);
      final stageName = stage['stage_name'];
      if (stageName != null && stageName.toString().trim().isNotEmpty) {
        return stageName.toString().trim();
      }
    } catch (_) {}

    return 'Phase $phaseNumber';
  }
}

/// Data class for project notification info
class ProjectNotification {
  final String projectId;
  final bool hasPendingAction;
  final String? actionType; // 'revert' or 'pending_review'
  final int? phaseNumber;
  final String? stageName;

  ProjectNotification({
    required this.projectId,
    required this.hasPendingAction,
    this.actionType,
    this.phaseNumber,
    this.stageName,
  });
}
