import 'package:get/get.dart';
import '../models/project.dart';
import '../models/project_membership.dart';
import '../services/project_membership_service.dart';
import '../services/template_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/projects_controller.dart';
import 'package:flutter/material.dart';
import '../widgets/incomplete_template_dialog.dart';

class MyProjectDetailController extends GetxController {
  MyProjectDetailController({required Project project, String? description})
    : project = project.obs,
      description = RxnString(description);

  final Rx<Project> project;
  final RxnString description;

  final isLoadingAssignments = true.obs;
  final teamLeaders = <ProjectMembership>[].obs;
  final executors = <ProjectMembership>[].obs;
  final reviewers = <ProjectMembership>[].obs;
  final starting = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAssignments();
  }

  Future<void> loadAssignments() async {
    isLoadingAssignments.value = true;
    try {
      if (Get.isRegistered<ProjectMembershipService>()) {
        final membershipService = Get.find<ProjectMembershipService>();
        final memberships = await membershipService.getProjectMembers(
          project.value.id,
        );
        teamLeaders.value = memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'teamleader')
            .toList();
        executors.value = memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'executor')
            .toList();
        reviewers.value = memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'reviewer')
            .toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[MyProjectDetailController] Error loading assignments: $e');
    } finally {
      isLoadingAssignments.value = false;
    }
  }

  bool get isChecklistAccessible {
    final statusLower = project.value.status.toLowerCase();
    // Only accessible when project is In Progress or Completed
    return statusLower == 'in progress' || statusLower == 'completed';
  }

  bool get showStartButton {
    if (isLoadingAssignments.value) return false;
    final statusLower = project.value.status.toLowerCase();
    if (statusLower == 'in progress' || statusLower == 'completed') {
      return false;
    }
    if (!Get.isRegistered<AuthController>()) return false;
    final auth = Get.find<AuthController>();
    final userId = auth.currentUser.value?.id;
    if (userId == null) return false;

    final isExecutor = executors.any((m) => m.userId == userId);
    final isReviewer = reviewers.any((m) => m.userId == userId);
    final assignedContainsUser = (project.value.assignedEmployees ?? [])
        .contains(userId);
    final fallback =
        assignedContainsUser && executors.isEmpty && reviewers.isEmpty;
    // ignore: avoid_print
    print(
      '[MyProjectDetailController] showStartButton status=${project.value.status} executors=${executors.length} reviewers=${reviewers.length} userId=$userId isExecutor=$isExecutor isReviewer=$isReviewer assignedContainsUser=$assignedContainsUser fallback=$fallback',
    );
    return isExecutor || isReviewer || fallback;
  }

  /// Validate template completeness before starting project
  /// Returns true if user wants to proceed, false otherwise
  Future<bool> _validateTemplate() async {
    try {
      if (!Get.isRegistered<TemplateService>()) {
        // If template service is not available, proceed without validation
        return true;
      }

      final templateService = Get.find<TemplateService>();
      final validation = await templateService.validateTemplateCompleteness();

      final isComplete = validation['isComplete'] as bool? ?? true;
      final incompletePhases =
          (validation['incompletePhases'] as List?)?.cast<String>() ?? [];

      if (!isComplete && incompletePhases.isNotEmpty) {
        // Show warning dialog and get user confirmation
        final proceed = await Get.dialog<bool>(
          IncompleteTemplateDialog(incompletePhases: incompletePhases),
          barrierDismissible: false,
        );

        return proceed ?? false;
      }

      return true;
    } catch (e) {
      // If validation fails, log error and let user proceed
      // ignore: avoid_print
      print('[MyProjectDetailController] Template validation error: $e');
      return true;
    }
  }

  Future<void> startProject() async {
    if (!Get.isRegistered<ProjectsController>()) return;

    // Validate template before starting
    final shouldProceed = await _validateTemplate();
    if (!shouldProceed) {
      // User cancelled, don't start the project
      return;
    }

    starting.value = true;
    final projectsCtrl = Get.find<ProjectsController>();
    final original = project.value;
    final updated = project.value.copyWith(
      started: DateTime.now(),
      status: 'In Progress',
    );
    try {
      final saved = await projectsCtrl.saveProjectRemote(updated);
      project.value = saved;
      Get.snackbar(
        'Success',
        'Project started',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      project.value = original; // rollback
      Get.snackbar(
        'Error',
        'Failed to start project: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      starting.value = false;
    }
  }
}
