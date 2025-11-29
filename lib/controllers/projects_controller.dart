import 'dart:async';
import 'package:get/get.dart';
import '../models/project.dart';
import '../services/project_service.dart';
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
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }
}
