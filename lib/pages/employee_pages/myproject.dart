import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import 'my_project_detail_page.dart';

class Myproject extends StatefulWidget {
  const Myproject({super.key});

  @override
  State<Myproject> createState() => _MyprojectState();
}

class _MyprojectState extends State<Myproject> {
  late final ProjectsController _ctrl;
  // Sorting & hover state (dashboard parity)
  String _sortKey = 'started';
  bool _ascending = false; // newest first
  int? _hoverIndex;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Mock current user
  final String currentUser = 'Emily Carter';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ProjectsController());
    if (_ctrl.projects.isEmpty) {
      _ctrl.loadInitial([
        Project(
          id: 'p1',
          title: 'Implement New CRM System',
          description:
              'Develop and implement a comprehensive CRM system to streamline sales & support.',
          started: DateTime(2024, 6, 1),
          priority: 'High',
          status: 'In Progress',
          executor: 'Emily Carter',
          assignedEmployees: ['Emily Carter', 'David Lee', 'Sophia Clark'],
        ),
        Project(
          id: 'p5',
          title: 'Mobile App Development',
          description:
              'Cross-platform mobile application for iOS & Android to enhance engagement.',
          started: DateTime(2024, 6, 15),
          priority: 'High',
          status: 'In Progress',
          executor: 'Emily Carter',
          assignedEmployees: ['Emily Carter', 'William Hall', 'Isabella King'],
        ),
        Project(
          id: 'p6',
          title: 'Website Redesign',
          description:
              'Modern UI/UX redesign with better performance and SEO improvements.',
          started: DateTime(2024, 5, 10),
          priority: 'Medium',
          status: 'Completed',
          executor: 'Emily Carter',
          assignedEmployees: ['Emily Carter', 'Ava Lewis'],
        ),
      ]);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openProjectDetails(Project project) {
    Get.to(
      () => MyProjectDetailPage(
        project: project,
        description: project.description,
      ),
    );
  }

  // Active projects for this user
  List<Project> get _myProjects =>
      _ctrl.projects.where((p) => p.executor == currentUser).toList();

  List<Project> get _visibleProjects {
    List<Project> list = _myProjects.toList();
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
              Text(
                'My Projects',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              // Search bar (same style as dashboard)
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Obx(() {
                    final projects = _visibleProjects;
                    if (projects.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No projects assigned to you',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        // Header row (sortable)
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
                            final hovered = _hoverIndex == index;
                            return MouseRegion(
                              onEnter: (_) =>
                                  setState(() => _hoverIndex = index),
                              onExit: (_) => setState(() => _hoverIndex = null),
                              child: GestureDetector(
                                onTap: () => _openProjectDetails(proj),
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
                                          // Keep title default color (remove blue styling)
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
                                      Expanded(
                                        flex: 1,
                                        child: Text(proj.status),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(proj.executor ?? '--'),
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
                ),
              ),
            ],
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
