import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/notification_controller.dart';
import 'my_project_detail_page.dart';
import '../../widgets/phase_overview_widget.dart';

class Myproject extends StatefulWidget {
  const Myproject({super.key});

  @override
  State<Myproject> createState() => _MyprojectState();
}

class _MyprojectState extends State<Myproject> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'started';
  bool _ascending = false;
  List<Project> _cachedProjects = [];
  bool _isInitialLoad = true;
  final Set<String> _selectedStatuses = {};
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _startNotificationPolling();
  }

  Future<void> _loadProjects({bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      final ctrl = Get.find<ProjectsController>();
      final authCtrl = Get.find<AuthController>();
      final userId = authCtrl.currentUser.value?.id;

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _cachedProjects = [];
            _isInitialLoad = false;
          });
        }
        return;
      }

      // Check if projects are already loaded (from login preload)
      final hasProjects = ctrl.projects.isNotEmpty;
      final alreadyHydrated = ctrl.projects.any(
        (p) => (p.assignedEmployees ?? []).isNotEmpty,
      );

      if (!hasProjects || !alreadyHydrated || forceRefresh) {
        // Need to refresh if no projects or not hydrated yet
        await ctrl.refreshProjects();

        // Small delay to ensure hydration completes (race condition fix)
        // Removed delay for faster loading
      } else {
        print('[MyProjects] Using preloaded projects (already hydrated)');
      }

      if (!mounted) return;

      // Use the controller's byAssigneeId method for more reliable filtering
      final myProjects = ctrl.byAssigneeId(userId);

      // Update notifications for all projects
      final notifCtrl = Get.find<NotificationController>();
      await notifCtrl.updateMultipleProjects(myProjects);

      // Debug logging
      print('[MyProjects] Loaded projects for user $userId:');
      print('[MyProjects] Total projects found: ${myProjects.length}');
      for (final p in myProjects) {
        print(
          '[MyProjects]   - ${p.title} (assignedEmployees: ${p.assignedEmployees})',
        );
      }

      if (mounted) {
        setState(() {
          _cachedProjects = myProjects;
          _isInitialLoad = false;
        });

        print('[MyProjects] Cached ${_cachedProjects.length} projects');
      }
    } catch (e) {
      print('[MyProjects] Error loading projects: $e');
      if (mounted) {
        setState(() {
          _cachedProjects = [];
          _isInitialLoad = false;
        });

        // Show error snackbar
        Get.snackbar(
          'Error',
          'Failed to load projects: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          mainButton: TextButton(
            onPressed: () => _loadProjects(forceRefresh: true),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _cachedProjects.isEmpty) return;
      try {
        final notifCtrl = Get.find<NotificationController>();
        await notifCtrl.updateMultipleProjects(_cachedProjects);
      } catch (_) {
        // Ignore transient notification refresh errors.
      }
    });
  }

  List<Project> _getMyProjects() {
    List<Project> list = _cachedProjects;

    // Apply status filter (empty means show all)
    if (_selectedStatuses.isNotEmpty) {
      list = list.where((p) => _selectedStatuses.contains(p.status)).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.status.toLowerCase().contains(query) ||
            p.priority.toLowerCase().contains(query) ||
            (p.executor ?? '').toLowerCase().contains(query);
      }).toList();
    }

    list.sort((a, b) {
      int result = 0;
      switch (_sortKey) {
        case 'title':
          result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'started':
          result = a.started.compareTo(b.started);
          break;
        case 'priority':
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          result = (order[a.priority] ?? 9).compareTo(order[b.priority] ?? 9);
          break;
        case 'status':
          result = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'executor':
          result = (a.executor ?? '').toLowerCase().compareTo(
            (b.executor ?? '').toLowerCase(),
          );
          break;
      }
      return _ascending ? result : -result;
    });

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

  Widget _buildFilterChip(String status) {
    final isSelected = _selectedStatuses.contains(status);
    return FilterChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedStatuses.add(status);
          } else {
            _selectedStatuses.remove(status);
          }
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[800],
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[900] : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _priorityChip(String priority) {
    Color bg = const Color(0xFFEFF3F7);
    if (priority == 'High') bg = const Color(0xFFFBEFEF);
    if (priority == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(priority, style: const TextStyle(fontSize: 12)),
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
                    'My Projects',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh projects',
                    onPressed: () => _loadProjects(forceRefresh: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                    hintText:
                        'Search by title, status, priority, created by...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Status filter chips
              Row(
                children: [
                  const Text(
                    'Filter by Status:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip('Not Started'),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed'),
                  const Spacer(),
                  if (_selectedStatuses.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedStatuses.clear();
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _isInitialLoad
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final projects = _getMyProjects();

                        if (projects.isEmpty) {
                          return Container(
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

                        return Container(
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
                            child: Column(
                              children: [
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
                                        flex: 2,
                                        child: const Text(
                                          'Project No.',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blueGrey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
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
                                        flex: 2,
                                        child: _HeaderCell(
                                          label: 'Priority',
                                          active: _sortKey == 'priority',
                                          ascending: _ascending,
                                          onTap: () => _toggleSort('priority'),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
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
                                          label: 'Created By',
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
                                    final project = projects[index];
                                    return _MyProjectCard(project: project);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyProjectCard extends StatefulWidget {
  final Project project;

  const _MyProjectCard({required this.project});

  @override
  State<_MyProjectCard> createState() => _MyProjectCardState();
}

class _MyProjectCardState extends State<_MyProjectCard> {
  bool _isHovered = false;

  Widget _priorityChip(String p) {
    Color bg = const Color(0xFFEFF3F7);
    if (p == 'High') bg = const Color(0xFFFBEFEF);
    if (p == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(p, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'not started':
        return const Color(0xFFFFF9E6);
      case 'in progress':
        return const Color(0xFFE3F2FD);
      case 'completed':
        return const Color(0xFFE8F5E9);
      default:
        return Colors.white;
    }
  }

  Color _getHoverColor(String status) {
    switch (status.toLowerCase()) {
      case 'not started':
        return const Color(0xFFFFF3CD);
      case 'in progress':
        return const Color(0xFFBBDEFB);
      case 'completed':
        return const Color(0xFFC8E6C9);
      default:
        return const Color(0xFFF7F9FC);
    }
  }

  Color _getBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'not started':
        return Colors.amber.shade300;
      case 'in progress':
        return Colors.blue.shade300;
      case 'completed':
        return Colors.green.shade300;
      default:
        return Colors.blue.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifCtrl = Get.find<NotificationController>();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => Get.to(() => MyProjectDetailPage(project: widget.project)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? _getHoverColor(widget.project.status)
                : _getStatusColor(widget.project.status),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered
                  ? _getBorderColor(widget.project.status)
                  : Colors.grey.shade300,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: _getBorderColor(
                        widget.project.status,
                      ).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          transform: _isHovered
              ? (Matrix4.identity()..translate(0.0, -2.0))
              : Matrix4.identity(),
          child: Obx(() {
            final notification = notifCtrl.getNotification(widget.project.id);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        (widget.project.projectNo?.trim().isNotEmpty ?? false)
                            ? widget.project.projectNo!.trim()
                            : '--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        widget.project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${widget.project.started.year}-${widget.project.started.month.toString().padLeft(2, '0')}-${widget.project.started.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _priorityChip(widget.project.priority),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(widget.project.status),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(widget.project.executor ?? '--'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Notification badge - positioned above phase overview (executor revert only)
                if ((notification?.hasPendingAction ?? false) &&
                    notification?.actionType == 'revert')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: notification?.actionType == 'revert'
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: notification?.actionType == 'revert'
                                  ? Colors.red.shade400
                                  : Colors.orange.shade400,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                notification?.actionType == 'revert'
                                    ? Icons.refresh
                                    : Icons.rate_review,
                                color: notification?.actionType == 'revert'
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  notification?.actionType == 'revert'
                                      ? 'Reverted: ${notification?.stageName ?? 'Phase ${notification?.phaseNumber ?? 0}'}'
                                      : 'Pending Review: ${notification?.stageName ?? 'Phase ${notification?.phaseNumber ?? 0}'}',
                                  style: TextStyle(
                                    color: notification?.actionType == 'revert'
                                        ? Colors.red.shade700
                                        : Colors.orange.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                PhaseOverviewWidget(
                  project: widget.project,
                  compact: true,
                  showTitle: false,
                ),
              ],
            );
          }),
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
