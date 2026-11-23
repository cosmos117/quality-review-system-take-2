import 'dart:async';

import 'package:get/get.dart';
import '../models/project.dart';
import '../services/project_service.dart';
import '../services/project_membership_service.dart';
import 'auth_controller.dart';

/// Holds cached membership names per project for reactive dashboard display.
class ProjectMembershipCache {
  final List<String> teamLeaders;
  final List<String> executors;
  final List<String> reviewers;
  const ProjectMembershipCache({
    this.teamLeaders = const [],
    this.executors = const [],
    this.reviewers = const [],
  });
}

class ProjectsController extends GetxController {
  final RxList<Project> projects = <Project>[].obs;
  final RxList<Project> userProjects = <Project>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// True when a background refresh is running but stale data is already visible.
  final RxBool isRefreshing = false.obs;

  /// Reactive cache: projectId -> membership names (team leaders, executors, reviewers).
  /// Dashboard cards observe this so they update instantly when memberships change.
  final membershipCache = <String, ProjectMembershipCache>{}.obs;

  List<Project> get all => projects;
  late final ProjectService _service;
  Timer? _refreshTimer;
  bool _hydratingInProgress = false;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<ProjectService>();
    refreshProjects();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshProjects(forceRefresh: true),
    );
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

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
      // Preserve userRole to prevent flickering during updates
      userRole: p.userRole,
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

  // Find projects where the user has the TeamLeader role
  List<Project> byTeamLeaderId(String userId) => projects
      .where(
        (p) =>
            p.userRole != null &&
            p.userRole!.toLowerCase().contains('teamleader'),
      )
      .toList();

  void loadInitial(List<Project> initial) {
    projects.assignAll(initial.map(_normalize));
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

  Future<Project> createProjectRemote(Project p) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final userId = authCtrl.currentUser.value?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      final created = await _service.create(p, userId: userId);
      await refreshProjects(forceRefresh: true);
      return created;
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<Project> saveProjectRemote(Project p) async {
    try {
      final saved = await _service.update(p);
      await refreshProjects(forceRefresh: true);
      return saved;
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> removeProjectRemoteAndRefresh(String id) async {
    try {
      await _service.delete(id);
      await refreshProjects(forceRefresh: true);
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> refreshProjects({bool forceRefresh = false}) async {
    try {
      // Only show full loading spinner on initial load (empty list).
      // For subsequent refreshes, show a lightweight indicator so stale
      // data remains visible while fresh data loads in the background.
      final isFirstLoad = projects.isEmpty;
      if (isFirstLoad) {
        isLoading.value = true;
      } else {
        isRefreshing.value = true;
      }

      final projectsList = await _service.getAll(forceRefresh: forceRefresh);
      projects.assignAll(projectsList.map(_normalize));
      // Hydrate assignment membership data after loading projects
      await _hydrateAssignments();
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Load projects for a specific user (optimized - no hydration needed).
  /// Stores user-specific projects in a separate list without modifying the global projects list.
  /// The global polling stream continues to run so the Dashboard always shows all projects.
  Future<void> loadUserProjects(String userId) async {
    try {
      // Only block UI on first load; use lightweight refresh for subsequent loads
      final isFirstLoad = userProjects.isEmpty;
      if (isFirstLoad) {
        isLoading.value = true;
      } else {
        isRefreshing.value = true;
      }
      errorMessage.value = '';
      final projectsList = await _service.getForUser(userId);
      userProjects.assignAll(projectsList.map(_normalize));
      isLoading.value = false;
      isRefreshing.value = false;
      // No hydration needed - data already included from backend
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      isRefreshing.value = false;
      rethrow;
    }
  }

  Future<void> _hydrateAssignments() async {
    // Prevent concurrent hydration runs (expensive N API calls)
    if (_hydratingInProgress) return;
    _hydratingInProgress = true;
    try {
      await _doHydrateAssignments();
    } finally {
      _hydratingInProgress = false;
    }
  }

  Future<void> _doHydrateAssignments() async {
    if (!Get.isRegistered<ProjectMembershipService>()) {
      return;
    }
    final membershipService = Get.find<ProjectMembershipService>();

    // Get current user ID for setting userRole
    final authCtrl = Get.find<AuthController>();
    final currentUserId = authCtrl.currentUser.value?.id;

    // Process all projects in parallel for faster hydration
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

          // Find current user's role in this project
          String? userRole;
          if (currentUserId != null &&
              currentUserId.isNotEmpty &&
              memberships.isNotEmpty) {
            final userMembership = memberships.firstWhere(
              (m) => m.userId == currentUserId,
              orElse: () => memberships.first,
            );
            if (userMembership.userId == currentUserId) {
              userRole = userMembership.roleName;
            }
          }

          final idx = projects.indexWhere((p) => p.id == project.id);
          if (idx != -1) {
            projects[idx] = _normalize(
              projects[idx].copyWith(
                assignedEmployees: ids,
                userRole: userRole,
              ),
            );
          }

          // Populate membership cache for dashboard
          membershipCache[project.id] = ProjectMembershipCache(
            teamLeaders: memberships
                .where((m) {
                  final role = (m.roleName?.toLowerCase() ?? '').replaceAll(
                    ' ',
                    '',
                  );
                  return role == 'teamleader';
                })
                .map((m) => m.userName ?? 'Unknown')
                .toList(),
            executors: memberships
                .where((m) => (m.roleName?.toLowerCase() ?? '') == 'executor')
                .map((m) => m.userName ?? 'Unknown')
                .toList(),
            reviewers: memberships
                .where((m) => (m.roleName?.toLowerCase() ?? '') == 'reviewer')
                .map((m) => m.userName ?? 'Unknown')
                .toList(),
          );
        } catch (e) {}
      }),
    );
  }

  /// Refresh membership cache for a single project. Call this after saving
  /// role assignments so the dashboard updates immediately.
  Future<void> refreshProjectMemberships(String projectId) async {
    if (!Get.isRegistered<ProjectMembershipService>()) return;
    try {
      final svc = Get.find<ProjectMembershipService>();
      final memberships = await svc.getProjectMembers(projectId);

      final newCache = ProjectMembershipCache(
        teamLeaders: memberships
            .where((m) {
              final role = (m.roleName?.toLowerCase() ?? '').replaceAll(
                ' ',
                '',
              );
              return role == 'teamleader';
            })
            .map((m) => m.userName ?? 'Unknown')
            .toList(),
        executors: memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'executor')
            .map((m) => m.userName ?? 'Unknown')
            .toList(),
        reviewers: memberships
            .where((m) => (m.roleName?.toLowerCase() ?? '') == 'reviewer')
            .map((m) => m.userName ?? 'Unknown')
            .toList(),
      );

      // Update cache: create new map to ensure observable notification
      final newMap = {...membershipCache};
      newMap[projectId] = newCache;
      membershipCache.assignAll(newMap);

      // Also update the project in the list with new assignedEmployees
      final idx = projects.indexWhere((p) => p.id == projectId);
      if (idx != -1) {
        final memberIds = memberships
            .map((m) => m.userId)
            .where((id) => id.trim().isNotEmpty)
            .toList();
        final updated = projects[idx].copyWith(assignedEmployees: memberIds);
        projects[idx] = _normalize(updated);
      }
    } catch (e) {}
  }
}
