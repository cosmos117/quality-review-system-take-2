import 'package:get/get.dart';
import '../models/project.dart';

class ProjectDetailsController extends GetxController {
  late final Project initial;

  // Reactive fields
  final Rx<Project> _project = Rx<Project>(
    Project(
      id: 'init',
      title: 'Untitled',
      started: DateTime.now(),
      priority: 'Medium',
      status: 'Not Started',
    ),
  );
  final RxSet<String> selectedMemberIds = <String>{}.obs;

  Project get project => _project.value;
  String get description => project.description ?? '';

  void seed(Project p, {Iterable<String>? assigned}) {
    _project.value = p;
    if (assigned != null) {
      selectedMemberIds
        ..clear()
        ..addAll(assigned);
    } else if (p.assignedEmployees != null) {
      selectedMemberIds
        ..clear()
        ..addAll(p.assignedEmployees!);
    }
  }

  void toggleMember(String id, bool value) {
    if (value) {
      selectedMemberIds.add(id);
    } else {
      selectedMemberIds.remove(id);
    }
  }

  void updateMeta({
    String? projectNo,
    String? internalOrderNo,
    String? title,
    DateTime? started,
    String? priority,
    String? status,
    String? executor,
    String? description,
  }) {
    final current = _project.value;
    _project.value = current.copyWith(
      projectNo: projectNo ?? current.projectNo,
      internalOrderNo: internalOrderNo ?? current.internalOrderNo,
      title: title ?? current.title,
      started: started ?? current.started,
      priority: (priority == null || priority.isEmpty)
          ? current.priority
          : priority,
      status: (status == null || status.isEmpty) ? current.status : status,
      executor: (executor == null || executor.isEmpty)
          ? current.executor
          : executor,
      description: description ?? current.description,
      assignedEmployees: selectedMemberIds.toList(),
    );
  }
}
