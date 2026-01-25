import 'dart:async';
import 'package:get/get.dart';
import '../models/project.dart';
import '../models/team_member.dart';
import '../services/project_service.dart';
import '../services/project_membership_service.dart';
import '../services/role_service.dart';
import '../services/user_service.dart';
import 'auth_controller.dart';

class ProjectsController extends GetxController {
  final RxList<Project> projects = <Project>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  List<Project> get all => projects;
  late final ProjectService _service;
  StreamSubscription? _projectsSubscription;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<ProjectService>();
    _startRealtimeSync();
  }

  void _startRealtimeSync() {
    isLoading.value = true;
    _projectsSubscription = _service.getProjectsStream().listen(
      (projectsList) {
        projects.assignAll(projectsList.map(_normalize));
        isLoading.value = false;
        errorMessage.value = '';
      },
      onError: (e) {
        errorMessage.value = e.toString();
        isLoading.value = false;
      },
    );
  }

  @override
  void onClose() {
    _projectsSubscription?.cancel();
    super.onClose();
  }

  // Find projects where a given employee name is executor
  List<Project> byExecutor(String name) => projects
      .where(
        (p) =>
            (p.executor?.trim().toLowerCase() ?? '') ==
            name.trim().toLowerCase(),
      )
      .toList();

  Project _normalize(Project p) {
    final allowedPriorities = {'Low', 'Medium', 'High'};
    final allowedStatuses = {
      'Pending',
      'In Progress',
      'Completed',
      'Not Started',
    };
    String priority = allowedPriorities.contains(p.priority)
        ? p.priority
        : 'Medium';
    String status = allowedStatuses.contains(p.status)
        ? p.status
        : 'Not Started';
    final exec = (p.executor?.trim().isNotEmpty ?? false)
        ? p.executor!.trim()
        : null;
    final assigned = (p.assignedEmployees ?? [])
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList();
    return p.copyWith(
      priority: priority,
      status: status,
      executor: exec,
      assignedEmployees: assigned.isEmpty ? null : assigned,
      title: p.title.trim().isEmpty ? 'Untitled' : p.title.trim(),
      description: (p.description?.trim().isNotEmpty ?? false)
          ? p.description!.trim()
          : null,
    );
  }

  // Find projects assigned to given employee id in assignedEmployees
  List<Project> byAssigneeId(String employeeId) => projects
      .where(
        (p) => (p.assignedEmployees ?? const []).any(
          (e) => e.trim() == employeeId.trim(),
        ),
      )
      .toList();

  void loadInitial(List<Project> initial) {
    projects.assignAll(initial.map(_normalize));
  }

  void addProject(Project p) {
    // optimistic update; backend create can be added later
    projects.add(_normalize(p));
  }

  void updateProject(String id, Project updated) {
    final idx = projects.indexWhere((e) => e.id == id);
    if (idx != -1) projects[idx] = _normalize(updated);
  }

  Future<void> fetchFromBackend(Future<List<Project>> Function() loader) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await loader();
      projects.assignAll(list.map(_normalize));
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void deleteProject(String id) {
    projects.removeWhere((e) => e.id == id);
  }

  Future<void> removeProjectRemote(String id) async {
    try {
      await _service.delete(id);
      deleteProject(id);
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<Project> createProjectRemote(Project p) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final userId = authCtrl.currentUser.value?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      final created = await _service.create(p, userId: userId);
      await refreshProjects();
      return created;
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<Project> saveProjectRemote(Project p) async {
    try {
      final saved = await _service.update(p);
      await refreshProjects();
      return saved;
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> removeProjectRemoteAndRefresh(String id) async {
    try {
      await _service.delete(id);
      await refreshProjects();
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> refreshProjects() async {
    try {
      final projectsList = await _service.getAll();
      projects.assignAll(projectsList.map(_normalize));
      // Hydrate assignment membership data after loading projects
      await _hydrateAssignments();
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  /// Bulk set project assignments (adds/removes memberships remotely then updates local state)
  Future<void> setProjectAssignments(
    String projectId,
    List<String> memberIds,
  ) async {
    try {
      final membershipService = Get.find<ProjectMembershipService>();
      // Determine a default role to assign
      String defaultRoleId = '';
      try {
        final roleService = Get.find<RoleService>();
        final roles = await roleService.getAll();
        if (roles.isNotEmpty) {
          // Prefer an "Executor" role if present
          final execRole = roles.firstWhere(
            (r) => r.roleName.trim().toLowerCase() == 'executor',
            orElse: () => roles.first,
          );
          defaultRoleId = execRole.id;
        }
      } catch (_) {
        // Ignore role fetch errors; will fail if no roleId
      }
      if (defaultRoleId.isEmpty) {
        throw Exception(
          'No roles available to assign members. Create at least one role first.',
        );
      }

      // Fetch fresh user list from backend to ensure valid IDs
      final userService = Get.isRegistered<UserService>()
          ? Get.find<UserService>()
          : null;
      List<TeamMember> backendUsers = [];
      if (userService != null) {
        try {
          backendUsers = await userService.getAll();
          // ignore: avoid_print        } catch (e) {
          // ignore: avoid_print        }
      }

      // Resolve incoming memberIds to valid backend user IDs
      final normalizedDesired = <String>{};
      for (final raw in memberIds) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;

        // Try direct ID match first
        var matched = backendUsers.firstWhere(
          (u) => u.id == trimmed,
          orElse: () => TeamMember(
            id: '',
            name: '',
            email: '',
            role: 'User',
            status: 'Active',
            dateAdded: '',
            lastActive: '',
          ),
        );

        // If no ID match, try name/email match
        if (matched.id.isEmpty) {
          matched = backendUsers.firstWhere(
            (u) =>
                u.name.trim().toLowerCase() == trimmed.toLowerCase() ||
                u.email.trim().toLowerCase() == trimmed.toLowerCase(),
            orElse: () => TeamMember(
              id: '',
              name: '',
              email: '',
              role: 'User',
              status: 'Active',
              dateAdded: '',
              lastActive: '',
            ),
          );
        }

        if (matched.id.isNotEmpty) {
          normalizedDesired.add(matched.id);
          // ignore: avoid_print        } else {
          // ignore: avoid_print        }
      }

      // Fetch existing memberships from backend
      // ignore: avoid_print      final existingMemberships = await membershipService.getProjectMembers(
        projectId,
      );
      final existingIds = existingMemberships.map((m) => m.userId).toSet();
      final desiredIds = normalizedDesired;

      // Debug logging to trace assignment diff calculations.
      // ignore: avoid_print      final toAdd = desiredIds.difference(existingIds);
      final toRemove = existingIds.difference(desiredIds);

      // ignore: avoid_print      // Apply additions
      for (final userId in toAdd) {
        // ignore: avoid_print        try {
          await membershipService.addMember(
            projectId: projectId,
            userId: userId,
            roleId: defaultRoleId,
          );
          // ignore: avoid_print        } catch (addError) {
          // ignore: avoid_print          rethrow;
        }
      }

      // Apply removals
      for (final userId in toRemove) {
        // ignore: avoid_print        await membershipService.removeMember(
          projectId: projectId,
          userId: userId,
        );
      }

      // Update local project assignedEmployees with final desired IDs
      final idx = projects.indexWhere((p) => p.id == projectId);
      if (idx != -1) {
        final updated = projects[idx].copyWith(
          assignedEmployees: desiredIds.toList(),
        );
        projects[idx] = _normalize(updated);
        // ignore: avoid_print      }
    } catch (e) {
      // ignore: avoid_print      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> _hydrateAssignments() async {
    if (!Get.isRegistered<ProjectMembershipService>()) {
      // ignore: avoid_print      return;
    }
    final membershipService = Get.find<ProjectMembershipService>();
    // ignore: avoid_print    // Process all projects in parallel for faster hydration
    await Future.wait(
      projects.map((project) async {
        try {
          final memberships = await membershipService.getProjectMembers(
            project.id,
          );
          final ids = memberships
              .map((m) => m.userId)
              .where((id) => id.trim().isNotEmpty)
              .toList();

          // ignore: avoid_print          final idx = projects.indexWhere((p) => p.id == project.id);
          if (idx != -1) {
            projects[idx] = _normalize(
              projects[idx].copyWith(assignedEmployees: ids),
            );
            // ignore: avoid_print          }
        } catch (e) {
          // ignore: avoid_print        }
      }),
    );

    // ignore: avoid_print  }
}
