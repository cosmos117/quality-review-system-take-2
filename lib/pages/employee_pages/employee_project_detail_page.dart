import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../controllers/team_controller.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/auth_controller.dart';

class EmployeeProjectDetailPage extends StatefulWidget {
  final Project project;
  final String? description;

  const EmployeeProjectDetailPage({
    super.key,
    required this.project,
    this.description,
  });

  @override
  State<EmployeeProjectDetailPage> createState() =>
      _EmployeeProjectDetailsPageState();
}

class _EmployeeProjectDetailsPageState
    extends State<EmployeeProjectDetailPage> {
  late final TeamController _teamCtrl;
  late final ProjectsController _projectsCtrl;
  late Set<String> _selectedMemberIds;
  late Project _project; // local mutable copy for live updates
  // Removed hardcoded currentUser; use AuthController when available.

  @override
  void initState() {
    super.initState();
    // Use existing controllers to avoid duplicate instances with empty data
    _teamCtrl = Get.isRegistered<TeamController>()
        ? Get.find<TeamController>()
        : Get.put(TeamController());
    _projectsCtrl = Get.isRegistered<ProjectsController>()
        ? Get.find<ProjectsController>()
        : Get.put(ProjectsController());
    _project = widget.project;
    // Initialize selection from project's existing assignedEmployees
    _selectedMemberIds = (widget.project.assignedEmployees ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final description = widget.description;
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (project.projectNo != null &&
                        project.projectNo!.isNotEmpty)
                      _row('Project No.', project.projectNo!),
                    if (project.internalOrderNo != null &&
                        project.internalOrderNo!.isNotEmpty)
                      _row(
                        'Project / Internal Order No.',
                        project.internalOrderNo!,
                      ),
                    _row('Title', project.title),
                    _row('Started', _formatDate(project.started)),
                    _row('Priority', project.priority),
                    _row('Status', project.status),
                    _row('Executor', project.executor ?? '--'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  description?.trim().isNotEmpty == true
                      ? description!
                      : 'No description provided.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assign Employees',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_selectedMemberIds.length} selected',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Obx(() {
                  final members = _teamCtrl.members;
                  if (members.isEmpty) {
                    return const Text('No employees found.');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final checked = _selectedMemberIds.contains(m.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedMemberIds.add(m.id);
                            } else {
                              _selectedMemberIds.remove(m.id);
                            }
                          });
                        },
                        title: Text(m.name),
                        subtitle: Text(m.email),
                        secondary: CircleAvatar(
                          child: Text(m.name.isNotEmpty ? m.name[0] : '?'),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final ids = _selectedMemberIds.toList();
                    try {
                      await _projectsCtrl.setProjectAssignments(
                        project.id,
                        ids,
                      );
                      setState(() {
                        _project = _project.copyWith(assignedEmployees: ids);
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Assignments saved')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Assignments'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMemberIds.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if ((_project.assignedEmployees ?? const []).isNotEmpty) ...[
              Text(
                'Currently Assigned',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (_project.assignedEmployees ?? const []).map((id) {
                  final member = _teamCtrl.findById(id);
                  final label = member?.name ?? id;
                  return Chip(label: Text(label));
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            if (project.status == 'Not Started')
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _onStartProject,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Project'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _onStartProject() {
    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final userName = auth?.currentUser.value?.name;
    if (userName == null || userName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start: user not authenticated')),
      );
      return;
    }
    final updated = _project.copyWith(
      status: 'In Progress',
      executor: userName.trim(),
    );
    _projectsCtrl.updateProject(_project.id, updated);
    setState(() => _project = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Project started')));
  }
}
