import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/team_controller.dart';
import '../../components/admin_dialog.dart';
import '../../controllers/project_details_controller.dart';
import '../../services/project_service.dart';

class AdminProjectDetailsPage extends StatefulWidget {
  final Project project;
  final String? descriptionOverride;

  const AdminProjectDetailsPage({
    super.key,
    required this.project,
    this.descriptionOverride,
  });

  @override
  State<AdminProjectDetailsPage> createState() =>
      _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> {
  late ProjectDetailsController _detailsCtrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _detailsCtrl = Get.put(
      ProjectDetailsController(),
      tag: widget.project.id,
      permanent: false,
    );
    _detailsCtrl.seed(widget.project);
    _fetchLatestProjectData();
  }

  Future<void> _fetchLatestProjectData() async {
    try {
      final projectService = Get.find<ProjectService>();
      final latestProject = await projectService.getById(widget.project.id);
      _detailsCtrl.seed(latestProject);
    } catch (e) {
      // If fetch fails, continue with the passed project data
      debugPrint('Failed to fetch latest project: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ProjectsController get _projectsCtrl => Get.find<ProjectsController>();
  TeamController get _teamCtrl => Get.find<TeamController>();
  ProjectDetailsController _details() => _detailsCtrl;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final details = _details();
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(details.project.title)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit project',
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, details),
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, details),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Obx(
              () => SingleChildScrollView(
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
                            if (details.project.projectNo != null &&
                                details.project.projectNo!.isNotEmpty)
                              _row('Project No.', details.project.projectNo!),
                            if (details.project.internalOrderNo != null &&
                                details.project.internalOrderNo!.isNotEmpty)
                              _row(
                                'Project / Internal Order No.',
                                details.project.internalOrderNo!,
                              ),
                            _row('Title', details.project.title),
                            _row(
                              'Started',
                              _formatDate(details.project.started),
                            ),
                            _row('Priority', details.project.priority),
                            _row('Status', details.project.status),
                            _row(
                              'Executor',
                              (details.project.executor?.trim().isNotEmpty ??
                                      false)
                                  ? details.project.executor!.trim()
                                  : '--',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Obx(() {
                          final desc = (details.project.description ?? '')
                              .trim();
                          return Text(
                            desc.isNotEmpty ? desc : 'No description provided.',
                            style: const TextStyle(height: 1.4),
                          );
                        }),
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
                          '${details.selectedMemberIds.length} selected',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Builder(
                          builder: (context) {
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
                                final checked = details.selectedMemberIds
                                    .contains(m.id);
                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (v) =>
                                      details.toggleMember(m.id, v == true),
                                  title: Text(m.name),
                                  subtitle: Text(m.email),
                                  secondary: CircleAvatar(
                                    child: Text(
                                      m.name.isNotEmpty ? m.name[0] : '?',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final ids = details.selectedMemberIds.toList();
                            try {
                              await _projectsCtrl.setProjectAssignments(
                                details.project.id,
                                ids,
                              );
                              details.updateMeta();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Assignments saved'),
                                  ),
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
                          onPressed: () => details.selectedMemberIds.clear(),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    details.selectedMemberIds.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Currently Assigned',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: details.selectedMemberIds.map((id) {
                                  final idx = _teamCtrl.members.indexWhere(
                                    (e) => e.id == id,
                                  );
                                  final name = idx != -1
                                      ? _teamCtrl.members[idx].name
                                      : id;
                                  return Chip(label: Text(name));
                                }).toList(),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    Get.delete<ProjectDetailsController>(tag: widget.project.id);
    super.dispose();
  }

  List<String> _executorNames() {
    final names = _teamCtrl.members
        .map((m) => m.name)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  Future<void> _showEditDialog(
    BuildContext context,
    ProjectDetailsController detailsCtrl,
  ) async {
    final formKey = GlobalKey<FormState>();
    final current = detailsCtrl.project;
    String? projectNo = current.projectNo;
    String? internalOrderNo = current.internalOrderNo;
    String title = current.title;
    DateTime started = current.started;
    String priority = current.priority;
    String status = current.status;
    String? executor = current.executor;
    String description = current.description ?? '';

    const allowedPriorities = ['High', 'Medium', 'Low'];
    const allowedStatuses = ['In Progress', 'Completed', 'Not Started'];
    if (!allowedPriorities.contains(priority)) priority = 'Medium';
    if (!allowedStatuses.contains(status)) status = 'Not Started';
    executor = (executor != null && executor.trim().isNotEmpty)
        ? executor.trim()
        : null;
    final executorNames = _executorNames();
    if (executor != null && !executorNames.contains(executor)) executor = null;

    await showAdminDialog(
      context,
      title: 'Edit Project',
      width: 900,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: projectNo,
              decoration: const InputDecoration(labelText: 'Project No.'),
              onSaved: (v) => projectNo = v?.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: internalOrderNo,
              decoration: const InputDecoration(
                labelText: 'Project / Internal Order No.',
              ),
              onSaved: (v) => internalOrderNo = v?.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: title,
              decoration: const InputDecoration(labelText: 'Project Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter title' : null,
              onSaved: (v) => title = v!.trim(),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: started,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) started = picked;
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Started Date *',
                  ),
                  controller: TextEditingController(text: _formatDate(started)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: priority,
              items: const [
                'High',
                'Medium',
                'Low',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => priority = v ?? priority,
              decoration: const InputDecoration(labelText: 'Priority *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                'In Progress',
                'Completed',
                'Not Started',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => status = v ?? status,
              decoration: const InputDecoration(labelText: 'Status *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: executor,
              items: executorNames
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => executor = v,
              decoration: const InputDecoration(
                labelText: 'Executor (optional)',
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Description *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            TextFormField(
              initialValue: description,
              minLines: 10,
              maxLines: 16,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Enter description...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter description' : null,
              onSaved: (v) => description = v!.trim(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      formKey.currentState?.save();
                      final updated = current.copyWith(
                        projectNo: projectNo,
                        internalOrderNo: internalOrderNo,
                        title: title,
                        started: started,
                        priority: priority,
                        status: status,
                        executor: (executor == null || executor!.isEmpty)
                            ? null
                            : executor,
                        description: description,
                      );
                      Navigator.of(context).pop();
                      try {
                        await _projectsCtrl.saveProjectRemote(updated);
                        // Fetch latest data from backend
                        final projectService = Get.find<ProjectService>();
                        final latestProject = await projectService.getById(
                          updated.id,
                        );
                        detailsCtrl.seed(latestProject);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Project updated')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    ProjectDetailsController detailsCtrl,
  ) async {
    await showAdminDialog(
      context,
      title: 'Delete Project',
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Are you sure you want to delete "${detailsCtrl.project.title}"? This action cannot be undone.',
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () async {
                  try {
                    Navigator.of(context).pop(); // Close dialog first
                    await _projectsCtrl.removeProjectRemoteAndRefresh(
                      detailsCtrl.project.id,
                    );
                    Get.back(); // Go back to project list
                    Get.snackbar(
                      'Deleted',
                      'Project has been deleted successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to delete project: ${e.toString()}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                child: const Text('Delete Project'),
              ),
            ],
          ),
        ],
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
}
