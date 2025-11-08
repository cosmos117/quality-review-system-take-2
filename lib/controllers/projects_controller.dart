import 'package:get/get.dart';
import '../models/project.dart';

class ProjectsController extends GetxController {
  final RxList<Project> projects = <Project>[].obs;

  List<Project> get all => projects;

  void loadInitial(List<Project> initial) {
    projects.assignAll(initial);
  }

  void addProject(Project p) {
    projects.add(p);
  }

  void updateProject(String id, Project updated) {
    final idx = projects.indexWhere((e) => e.id == id);
    if (idx != -1) projects[idx] = updated;
  }

  void deleteProject(String id) {
    projects.removeWhere((e) => e.id == id);
  }
}
