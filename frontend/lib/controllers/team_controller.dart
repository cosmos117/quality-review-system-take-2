import 'dart:async';
import 'package:get/get.dart';
import '../models/team_member.dart';
import '../services/user_service.dart';

class TeamController extends GetxController {
  final RxList<TeamMember> members = <TeamMember>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  late final UserService _service;
  StreamSubscription? _usersSubscription;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<UserService>();
    _startRealtimeSync();
  }

  void _startRealtimeSync() {
    isLoading.value = true;
    _usersSubscription = _service.getUsersStream().listen(
      (usersList) {
        members.assignAll(usersList.map(_normalize));
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
    _usersSubscription?.cancel();
    super.onClose();
  }

  TeamMember _normalize(TeamMember m) {
    final name = m.name.trim();
    final email = m.email.trim();
    final role = m.role.trim();
    return m.copyWith(name: name, email: email, role: role);
  }

  void loadInitial(List<TeamMember> initial) {
    members.assignAll(initial.map(_normalize));
  }

  void addMember(TeamMember m) => members.insert(0, _normalize(m));
  void updateMember(String id, TeamMember updated) {
    final idx = members.indexWhere((e) => e.id == id);
    if (idx != -1) members[idx] = _normalize(updated);
  }

  void deleteMember(String id) => members.removeWhere((e) => e.id == id);

  // Backend-powered CRUD helpers
  Future<void> createMember(TeamMember m) async {
    try {
      await _service.create(m);
      // Immediately refresh the list
      await refreshMembers();
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> saveMember(TeamMember m) async {
    try {
      await _service.update(m);
      // Immediately refresh the list
      await refreshMembers();
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> removeMember(String id) async {
    try {
      await _service.delete(id);
      // Immediately refresh the list
      await refreshMembers();
    } catch (e) {
      errorMessage.value = e.toString();
      rethrow;
    }
  }

  Future<void> refreshMembers() async {
    try {
      final users = await _service.getAll();
      members.assignAll(users.map(_normalize));
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  // Simple filters stored as reactive values
  final RxList<String> selectedRoles = <String>[].obs;
  final RxList<String> selectedStatuses = <String>[].obs;
  // Search query for name/email filtering
  final RxString searchQuery = ''.obs;

  List<TeamMember> get filtered {
    // Work on a plain List derived from the reactive members to make filtering predictable.
    List<TeamMember> list = members.toList();
    if (selectedRoles.isNotEmpty) {
      list = list.where((m) => selectedRoles.contains(m.role)).toList();
    }
    if (selectedStatuses.isNotEmpty) {
      list = list.where((m) => selectedStatuses.contains(m.status)).toList();
    }
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) {
        return m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void clearFilters() {
    selectedRoles.clear();
    selectedStatuses.clear();
    searchQuery.value = '';
  }

  TeamMember? findById(String id) {
    final idx = members.indexWhere((m) => m.id == id);
    return idx == -1 ? null : members[idx];
  }

  Future<void> fetchFromBackend(
    Future<List<TeamMember>> Function() loader,
  ) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final list = await loader();
      members.assignAll(list.map(_normalize));
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
