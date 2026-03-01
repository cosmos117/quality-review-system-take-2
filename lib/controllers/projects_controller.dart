import 'dart:async';
import 'package:get/get.dart';
import '../models/project.dart';
import '../models/team_member.dart';
import '../services/project_service.dart';
import '../services/project_membership_service.dart';
import '../services/role_service.dart';
import '../services/user_service.dart';
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
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// Reactive cache: projectId → membership names (team leaders, executors, reviewers).
  /// Dashboard cards observe this so they update instantly when memberships change.
  final membershipCache = <String, ProjectMembershipCache>{}.obs;

  List<Project> get all => projects;
  late final ProjectService _service;
  StreamSubscription? _projectsSubscription;
  bool _hydratingInProgress = false;

  /// True when in user-specific mode (employee side); the global polling
  /// stream is paused to prevent it from overwriting user-filtered data.
  bool _userMode = false;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<ProjectService>();
    _startRealtimeSync();
  }

  void _startRealtimeSync() {
    _projectsSubscription?.cancel();
    _userMode = false;
    isLoading.value = true;
    _projectsSubscription = _service.getProjectsStream().listen(
      (projectsList) async {
        // Skip if we switched to user-specific mode while waiting
        if (_userMode) return;
        projects.assignAll(projectsList.map(_normalize));
        // Hydrate assignments for each project
        await _hydrateAssignments();
        if (!_userMode) isLoading.value = false;
        errorMessage.value = '';
      },
      onError: (e) {
        errorMessage.value = e.toString();
        isLoading.value = false;
      },
    );
  }

  /// Restart the global polling stream (call from admin pages if needed).
  void ensureRealtimeSync() {
    if (!_userMode) return; // already running
    _startRealtimeSync();
  }

  /// Stop the global polling stream (used when switching to employee view).
  void stopRealtimeSync() {
    _projectsSubscription?.cancel();
    _projectsSubscription = null;
    _userMode = true;
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

  /// Load projects for a specific user (optimized - no hydration needed).
  /// Cancels the global polling stream to prevent it from overwriting
  /// user-specific data with ALL projects + expensive hydration.
  Future<void> loadUserProjects(String userId) async {
    try {
      // Stop the global polling stream – employees don't need all-project sync
      stopRealtimeSync();
      isLoading.value = true;
      errorMessage.value = '';
      final projectsList = await _service.getForUser(userId);
      projects.assignAll(projectsList.map(_normalize));
      isLoading.value = false;
      // No hydration needed - data already included from backend
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      rethrow;
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
          // ignore: avoid_print
          print(
            '[ProjectsController] Fetched ${backendUsers.length} users from backend',
          );
        } catch (e) {
          // ignore: avoid_print
          print('[ProjectsController] Failed to fetch users: $e');
        }
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
          // ignore: avoid_print
          print(
            '[ProjectsController] Resolved "$trimmed" → userId=${matched.id} (${matched.name})',
          );
        } else {
          // ignore: avoid_print
          print(
            '[ProjectsController] WARNING: Could not resolve "$trimmed" to any backend user - SKIPPING',
          );
        }
      }

      // Fetch existing memberships from backend
      // ignore: avoid_print
      print(
        '[ProjectsController] Fetching existing memberships for project=$projectId',
      );
      final existingMemberships = await membershipService.getProjectMembers(
        projectId,
      );
      final existingIds = existingMemberships.map((m) => m.userId).toSet();
      final desiredIds = normalizedDesired;

      // Debug logging to trace assignment diff calculations.
      // ignore: avoid_print
      print(
        '[ProjectsController] setProjectAssignments project=$projectId\n  existingIds=$existingIds\n  incomingMemberIds=$memberIds\n  normalizedDesired=$desiredIds',
      );

      final toAdd = desiredIds.difference(existingIds);
      final toRemove = existingIds.difference(desiredIds);

      // ignore: avoid_print
      print(
        '[ProjectsController] Diff result -> toAdd=$toAdd toRemove=$toRemove',
      );

      // Apply additions
      for (final userId in toAdd) {
        // ignore: avoid_print
        print(
          '[ProjectsController] Adding userId=$userId roleId=$defaultRoleId',
        );
        try {
          await membershipService.addMember(
            projectId: projectId,
            userId: userId,
            roleId: defaultRoleId,
          );
          // ignore: avoid_print
          print('[ProjectsController] ✓ Successfully added userId=$userId');
        } catch (addError) {
          // ignore: avoid_print
          print(
            '[ProjectsController] ✗ FAILED to add userId=$userId: $addError',
          );
          rethrow;
        }
      }

      // Apply removals
      for (final userId in toRemove) {
        // ignore: avoid_print
        print('[ProjectsController] Removing userId=$userId');
        await membershipService.removeMember(
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
        // ignore: avoid_print
        print(
          '[ProjectsController] ✓✓✓ setProjectAssignments SUCCESS: Updated project "${projects[idx].title}" with assignedEmployees=${desiredIds.toList()}',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ProjectsController] ✗✗✗ setProjectAssignments FAILED: $e');
      errorMessage.value = e.toString();
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
      // ignore: avoid_print
      print(
        '[ProjectsController] _hydrateAssignments: ProjectMembershipService not registered',
      );
      return;
    }
    final membershipService = Get.find<ProjectMembershipService>();

    // Get current user ID for setting userRole
    final authCtrl = Get.find<AuthController>();
    final currentUserId = authCtrl.currentUser.value?.id;

    // ignore: avoid_print
    print(
      '[ProjectsController] _hydrateAssignments: Starting for ${projects.length} projects (currentUserId=$currentUserId)',
    );

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
          if (currentUserId != null && currentUserId.isNotEmpty) {
            final userMembership = memberships.firstWhere(
              (m) => m.userId == currentUserId,
              orElse: () => memberships.first,
            );
            if (userMembership.userId == currentUserId) {
              userRole = userMembership.roleName;
            }
          }

          // ignore: avoid_print
          print(
            '[ProjectsController] Project "${project.title}" (${project.id}): Found ${memberships.length} memberships → userIds=$ids, userRole=$userRole',
          );

          final idx = projects.indexWhere((p) => p.id == project.id);
          if (idx != -1) {
            projects[idx] = _normalize(
              projects[idx].copyWith(
                assignedEmployees: ids,
                userRole: userRole,
              ),
            );
            // ignore: avoid_print
            print(
              '[ProjectsController] ✓ Updated project "${project.title}" assignedEmployees=$ids, userRole=$userRole',
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
        } catch (e) {
          // ignore: avoid_print
          print(
            '[ProjectsController] ✗ Failed to hydrate assignments for project "${project.title}": $e',
          );
        }
      }),
    );

    // ignore: avoid_print
    print('[ProjectsController] _hydrateAssignments: Complete');
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

      print(
        '[ProjectsController] ✓ Refreshed memberships for project=$projectId',
      );
    } catch (e) {
      print(
        '[ProjectsController] refreshProjectMemberships($projectId) failed: $e',
      );
    }
  }
}
