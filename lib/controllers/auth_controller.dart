import 'dart:convert';
import 'package:get/get.dart';
import 'package:quality_review/controllers/projects_controller.dart';
import 'package:quality_review/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

class AuthController extends GetxController {
  final Rx<AuthUser?> currentUser = Rx<AuthUser?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isPreloadingProjects = false.obs;
  final _service = AuthService();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('auth_user');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final user = AuthUser(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        role: data['role'],
        token: data['token'] ?? '',
      );
      _applyToken(user.token);
      currentUser.value = user;
    }
  }

  void _applyToken(String token) {
    if (Get.isRegistered<SimpleHttp>()) {
      Get.find<SimpleHttp>().accessToken = token;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    isLoading.value = true;
    try {
      final user = await _service.login(email, password);
      _applyToken(user.token);
      currentUser.value = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(user.toJson()));
      return user;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    currentUser.value = null;
    _applyToken('');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user');
  }

  /// Preload projects for employee after login to ensure consistent data
  Future<void> preloadEmployeeProjects() async {
    if (currentUser.value == null) return;

    final role = currentUser.value!.role.toLowerCase();
    if (role == 'admin') return; // Only for employees

    isPreloadingProjects.value = true;
    try {
      if (Get.isRegistered<ProjectsController>()) {
        final projectsCtrl = Get.find<ProjectsController>();
        final userId = currentUser.value!.id;

        // Use optimized endpoint - no hydration needed
        await projectsCtrl.loadUserProjects(userId);

        final myProjects = projectsCtrl.byAssigneeId(userId);

        print(
          '[AuthController] Preloaded ${myProjects.length} projects for employee $userId',
        );
      }
    } catch (e) {
      print('[AuthController] Error preloading projects: $e');
    } finally {
      isPreloadingProjects.value = false;
    }
  }
}
