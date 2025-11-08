import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/project.dart';
import '../../controllers/team_controller.dart';
import '../../controllers/projects_controller.dart';
import '../../models/team_member.dart';

// In-memory assignment store (per project) until backend integration
final Map<String, Set<String>> _assignedMembersByProject = {};

class AdminProjectDetailsPage extends StatefulWidget {
  final Project project;
  final String? description;

  const AdminProjectDetailsPage({super.key, required this.project, this.description});

  @override
  State<AdminProjectDetailsPage> createState() => _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> {
  late final TeamController _teamCtrl;
  late final ProjectsController _projectsCtrl;
  late Project _project;
  late Set<String> _selectedMemberIds;
  late String _description;

  @override
  void initState() {
    super.initState();
    _teamCtrl = Get.put(TeamController());
  _projectsCtrl = Get.find<ProjectsController>();
  _project = widget.project;
  _description = (widget.description ?? widget.project.description ?? '').trim();
    if (_teamCtrl.members.isEmpty) {
      // Optional seed if controller is empty (can be removed when backend wired)
      _teamCtrl.loadInitial([
        TeamMember(id: 't1', name: 'Emma Carter', email: 'emma.carter@example.com', role: 'Team Leader', status: 'Active', dateAdded: '2023-08-15', lastActive: '2024-05-20'),
        TeamMember(id: 't2', name: 'Liam Walker', email: 'liam.walker@example.com', role: 'Member', status: 'Active', dateAdded: '2023-09-22', lastActive: '2024-05-21'),
        TeamMember(id: 't3', name: 'Olivia Harris', email: 'olivia.harris@example.com', role: 'Reviewer', status: 'Inactive', dateAdded: '2023-10-10', lastActive: '2024-04-30'),
      ]);
    }
    _selectedMemberIds = (_assignedMembersByProject[widget.project.id] ?? <String>{}).toSet();
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          IconButton(
            tooltip: 'Edit project',
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(Icons.delete_outline),
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Title', project.title),
                    _row('Started', _formatDate(project.started)),
                    _row('Priority', (project.priority).toString()),
                    _row('Status', (project.status).toString()),
                    _row('Executor', (project.executor?.trim().isNotEmpty ?? false) ? project.executor!.trim() : '--'),
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
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Align(
                       alignment: Alignment.centerLeft,
                       child: Padding(
                         padding: EdgeInsets.only(bottom: 6),
                         child: Text('Description *', style: TextStyle(fontWeight: FontWeight.w600)),
                       ),
                     ),
                     TextFormField(
                       initialValue: _description.isNotEmpty ? _description : '',
                       minLines: 10,
                       maxLines: 16,
                       textAlignVertical: TextAlignVertical.top,
                       decoration: const InputDecoration(
                         hintText: 'Enter description...',
                         border: OutlineInputBorder(),
                         contentPadding: EdgeInsets.all(12),
                       ),
                       validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter description' : null,
                       onSaved: (v) => _description = v!.trim(),
                     ),
                   ],
                 ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assign Employees', style: Theme.of(context).textTheme.titleMedium),
                Text('${_selectedMemberIds.length} selected', style: const TextStyle(color: Colors.grey)),
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
                        secondary: CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0] : '?')),
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
                  onPressed: () {
                    setState(() {
                      _assignedMembersByProject[project.id] = _selectedMemberIds.toSet();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignments saved')));
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
            if ((_assignedMembersByProject[project.id] ?? {}).isNotEmpty) ...[
              Text('Currently Assigned', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (_assignedMembersByProject[project.id]!)
                    .map((id) {
                      final idx = _teamCtrl.members.indexWhere((e) => e.id == id);
                      final name = idx != -1 ? _teamCtrl.members[idx].name : id;
                      return Chip(label: Text(name));
                    })
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _executorNames() {
    final names = _teamCtrl.members.map((m) => m.name).where((e) => e.trim().isNotEmpty).toSet().toList();
    names.sort();
    if (names.isEmpty) {
      return const ['Emma Carter','Liam Walker','Olivia Harris','Noah Clark','Ava Lewis','William Hall','Sophia Young','James Wright','Isabella King'];
    }
    return names;
  }

  Future<void> _showEditDialog() async {
    final formKey = GlobalKey<FormState>();
    String title = _project.title;
    DateTime started = _project.started;
    String priority = _project.priority;
    String status = _project.status;
    String? executor = _project.executor;
  String description = _description;

  // Normalize initial values to avoid null / invalid enum issues
  const allowedPriorities = ['High', 'Medium', 'Low'];
  const allowedStatuses = ['In Progress', 'Completed', 'Not Started'];
  if (!allowedPriorities.contains(priority)) priority = 'Medium';
  if (!allowedStatuses.contains(status)) status = 'Not Started';
  executor = (executor != null && executor.trim().isNotEmpty) ? executor.trim() : null;
  final executorNames = _executorNames();
  if (executor != null && !executorNames.contains(executor)) executor = null;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Edit Project Dialog',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondary, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 900,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Edit Project',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close dialog',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Single column fields for production consistency
                        TextFormField(
                          initialValue: title,
                          decoration: const InputDecoration(labelText: 'Project Title *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter title' : null,
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
                            if (picked != null) setState(() => started = picked);
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: 'Started Date *'),
                              controller: TextEditingController(
                                text: '${started.year}-${started.month.toString().padLeft(2,'0')}-${started.day.toString().padLeft(2,'0')}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Description at bottom
                        
                        DropdownButtonFormField<String>(
                          initialValue: priority,
                          items: const ['High', 'Medium', 'Low']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => priority = v ?? priority,
                          decoration: const InputDecoration(labelText: 'Priority *'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          items: const ['In Progress', 'Completed', 'Not Started']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
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
                          decoration: const InputDecoration(labelText: 'Executor (optional)'),
                        ),
                        const SizedBox(height: 12),
                         TextFormField(
                          initialValue: description,
                          minLines: 10,
                          maxLines: 16,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                            hintText: 'Enter description...',
                            alignLabelWithHint: true,
                            contentPadding: EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter description' : null,
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
                              onPressed: () {
                                if (formKey.currentState?.validate() ?? false) {
                                  formKey.currentState?.save();
                                  final updated = _project.copyWith(
                                    title: title,
                                    started: started,
                                    priority: priority,
                                    status: status,
                                    executor: (executor == null || executor!.isEmpty) ? null : executor,
                                    description: description,
                                  );
                                  _projectsCtrl.updateProject(_project.id, updated);
                                  setState(() {
                                    _project = updated;
                                    _description = description;
                                  });
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Project updated')),
                                  );
                                }
                              },
                              child: const Text('Save Changes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Delete Project Dialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondary, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delete Project',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close dialog',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to delete "${_project.title}"? This action cannot be undone.',
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
                          onPressed: () {
                            _projectsCtrl.deleteProject(_project.id);
                            Navigator.of(context).pop();
                            Get.back();
                            Get.snackbar(
                              'Deleted',
                              'Project has been deleted',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          child: const Text('Delete Project'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}