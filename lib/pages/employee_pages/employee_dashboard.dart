import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/employee_pages/employee_project_detail_page.dart';

import '../../models/project.dart';
import '../../controllers/projects_controller.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboard> {
  late final ProjectsController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'started';
  bool _ascending = false; // default: newest first
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ProjectsController());

    if (_ctrl.projects.isEmpty) {
      _ctrl.loadInitial([
        Project(
          id: 'p1',
          title: 'Implement New CRM System',
          started: DateTime(2024, 6, 1),
          priority: 'High',
          status: 'In Progress',
          executor: 'Emily Carter',
        ),
        Project(
          id: 'p2',
          title: 'Develop Marketing Strategy',
          started: DateTime(2024, 5, 20),
          priority: 'Medium',
          status: 'Completed',
          executor: 'David Lee',
        ),
        Project(
          id: 'p3',
          title: 'Conduct Market Research',
          started: DateTime(2024, 6, 10),
          priority: 'Low',
          status: 'Not Started',
          executor: null,
        ),
        Project(
          id: 'p4',
          title: 'Build Analytics Dashboard',
          started: DateTime(2024, 5, 5),
          priority: 'High',
          status: 'In Progress',
          executor: 'Sophia Clark',
        ),
      ]);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Project> get _visibleProjects {
    List<Project> list = _ctrl.projects.toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final exec = p.executor ?? '';
        return p.title.toLowerCase().contains(q) ||
            p.status.toLowerCase().contains(q) ||
            p.priority.toLowerCase().contains(q) ||
            exec.toLowerCase().contains(q);
      }).toList();
    }
    int cmp(Project a, Project b) {
      int res = 0;
      switch (_sortKey) {
        case 'title':
          res = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'started':
          res = a.started.compareTo(b.started);
          break;
        case 'priority':
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          res = (order[a.priority] ?? 9).compareTo(order[b.priority] ?? 9);
          break;
        case 'status':
          res = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'executor':
          res = (a.executor ?? '').toLowerCase().compareTo(
            (b.executor ?? '').toLowerCase(),
          );
          break;
      }
      return _ascending ? res : -res;
    }

    list.sort(cmp);
    return list;
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = true;
      }
    });
  }

  List<String> get _executors => const [
    'Emma Carter',
    'Liam Walker',
    'Olivia Harris',
    'Noah Clark',
    'Ava Lewis',
    'William Hall',
    'Sophia Young',
    'James Wright',
    'Isabella King',
  ];
  // ...

  Widget _priorityChip(String p) {
    Color bg = const Color(0xFFEFF3F7);
    if (p == 'High') bg = const Color(0xFFFBEFEF);
    if (p == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(p, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search by title, status, priority, executor...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 16),
              // Tabular layout using ListView + Rows
              Obx(() {
                final projects = _visibleProjects;
                return Column(
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _HeaderCell(
                              label: 'Project Title',
                              active: _sortKey == 'title',
                              ascending: _ascending,
                              onTap: () => _toggleSort('title'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Started',
                              active: _sortKey == 'started',
                              ascending: _ascending,
                              onTap: () => _toggleSort('started'),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: _HeaderCell(
                              label: 'Priority',
                              active: _sortKey == 'priority',
                              ascending: _ascending,
                              onTap: () => _toggleSort('priority'),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: _HeaderCell(
                              label: 'Status',
                              active: _sortKey == 'status',
                              ascending: _ascending,
                              onTap: () => _toggleSort('status'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _HeaderCell(
                              label: 'Executor',
                              active: _sortKey == 'executor',
                              ascending: _ascending,
                              onTap: () => _toggleSort('executor'),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final proj = projects[index];
                        final executor =
                            (proj.status == 'In Progress' ||
                                proj.status == 'Completed')
                            ? (proj.executor ?? '--')
                            : '--';
                        final hovered = _hoverIndex == index;
                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoverIndex = index),
                          onExit: (_) => setState(() => _hoverIndex = null),
                          child: GestureDetector(
                            onTap: () => Get.to(
                              () => EmployeeProjectDetailPage(
                                project: proj,
                                description: _descriptions[proj.id],
                              ),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: hovered
                                    ? const Color(0xFFF7F9FC)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hovered
                                      ? Colors.blue.shade200
                                      : Colors.black12,
                                ),
                                boxShadow: hovered
                                    ? const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      proj.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${proj.started.year}-${proj.started.month.toString().padLeft(2, '0')}-${proj.started.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: _priorityChip(proj.priority),
                                  ),
                                  Expanded(flex: 1, child: Text(proj.status)),
                                  Expanded(flex: 2, child: Text(executor)),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Edit',
                                          onPressed: () =>
                                              _showEditDialog(proj),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          tooltip: 'Delete',
                                          onPressed: () =>
                                              _showDeleteDialog(proj),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Project project) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Edit Project Dialog',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: _ProjectFormDialog(
              title: 'Edit Project',
              executors: _executors,
              titleValidator: (t) {
                final exists = _ctrl.projects.any(
                  (p) =>
                      p.id != project.id &&
                      p.title.toLowerCase() == t.toLowerCase(),
                );
                return exists
                    ? 'A project with this title already exists'
                    : null;
              },
              width: 760,
              initial: ProjectFormData(
                title: project.title,
                started: project.started,
                priority: project.priority,
                status: project.status,
                executor: project.executor ?? '',
                description: _descriptions[project.id] ?? '',
              ),
              onSubmit: (data) {
                final updated = project.copyWith(
                  title: data.title,
                  started: data.started,
                  priority: data.priority,
                  status: data.status,
                  executor: (data.executor?.isEmpty ?? true)
                      ? null
                      : data.executor,
                );
                _ctrl.updateProject(project.id, updated);
                _descriptions[project.id] = data.description;
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteDialog(Project project) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Delete Project Dialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Container(
              width: 420,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to delete "${project.title}"? This action cannot be undone.',
                  ),
                  const SizedBox(height: 20),
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
                          _ctrl.deleteProject(project.id);
                          _descriptions.remove(project.id);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Project deleted')),
                          );
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Temporary in-memory descriptions store (until Project model updated globally).
  final Map<String, String> _descriptions = {};
}

class ProjectFormData {
  String title;
  DateTime started;
  String priority;
  String status;
  String? executor;
  String description;
  ProjectFormData({
    required this.title,
    required this.started,
    required this.priority,
    required this.status,
    required this.executor,
    required this.description,
  });
}

class _ProjectFormDialog extends StatefulWidget {
  final String title;
  final ProjectFormData? initial;
  final void Function(ProjectFormData data) onSubmit;
  final List<String>? executors;
  final String? Function(String)? titleValidator;
  final double? width;
  final bool showStatus;
  final bool showExecutor;
  const _ProjectFormDialog({
    required this.title,
    this.initial,
    required this.onSubmit,
    this.executors,
    this.titleValidator,
    this.width,
    this.showStatus = true,
    this.showExecutor = true,
  });

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late ProjectFormData data;

  @override
  void initState() {
    super.initState();
    data =
        widget.initial ??
        ProjectFormData(
          title: '',
          started: DateTime.now(),
          priority: 'Medium',
          status: 'Not Started',
          executor: '',
          description: '',
        );
  }

  String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width ?? 520,
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
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 600;
                    final List<Widget> fields = [
                      // Title
                      TextFormField(
                        initialValue: data.title,
                        decoration: const InputDecoration(
                          labelText: 'Project Title *',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Enter title';
                          if (widget.titleValidator != null) {
                            return widget.titleValidator!(v.trim());
                          }
                          return null;
                        },
                        onSaved: (v) => data.title = v!.trim(),
                      ),
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: data.started,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null)
                            setState(() => data.started = picked);
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Started Date *',
                            ),
                            controller: TextEditingController(
                              text: _dateString(data.started),
                            ),
                          ),
                        ),
                      ),
                      // Priority
                      DropdownButtonFormField<String>(
                        initialValue: data.priority,
                        items: ['High', 'Medium', 'Low']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => data.priority = v ?? data.priority),
                        decoration: const InputDecoration(
                          labelText: 'Priority *',
                        ),
                      ),
                      // Description
                      TextFormField(
                        initialValue: data.description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter description'
                            : null,
                        onSaved: (v) => data.description = v!.trim(),
                      ),
                    ];
                    if (widget.showStatus) {
                      fields.insert(
                        3,
                        DropdownButtonFormField<String>(
                          initialValue: data.status,
                          items: ['In Progress', 'Completed', 'Not Started']
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => data.status = v ?? data.status),
                          decoration: const InputDecoration(
                            labelText: 'Status *',
                          ),
                        ),
                      );
                    }
                    if (widget.showExecutor) {
                      fields.insert(
                        widget.showStatus ? 4 : 3,
                        DropdownButtonFormField<String>(
                          initialValue: (data.executor?.isEmpty ?? true)
                              ? null
                              : data.executor,
                          items:
                              (widget.executors ??
                                      const [
                                        'Emma Carter',
                                        'Liam Walker',
                                        'Olivia Harris',
                                        'Noah Clark',
                                        'Ava Lewis',
                                        'William Hall',
                                        'Sophia Young',
                                        'James Wright',
                                        'Isabella King',
                                      ])
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text(n),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) =>
                              setState(() => data.executor = v ?? ''),
                          decoration: const InputDecoration(
                            labelText: 'Executor (optional)',
                          ),
                        ),
                      );
                    }
                    if (!wide) {
                      return Column(
                        children: [
                          for (int i = 0; i < fields.length; i++) ...[
                            fields[i],
                            if (i != fields.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }
                    // Two-column grid for wide layout
                    final half = (constraints.maxWidth - 24) / 2;
                    return Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        for (final f in fields) SizedBox(width: half, child: f),
                      ],
                    );
                  },
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
                        if (_formKey.currentState?.validate() ?? false) {
                          _formKey.currentState?.save();
                          widget.onSubmit(data);
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(widget.initial == null ? 'Create' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  const _HeaderCell({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active
        ? (ascending
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded)
        : Icons.unfold_more_rounded;
    final color = active ? Colors.blueGrey[800] : Colors.blueGrey[600];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, size: 16, color: color),
        ],
      ),
    );
  }
}
