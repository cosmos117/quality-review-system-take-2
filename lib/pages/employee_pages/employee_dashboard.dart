import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/employee_pages/employee_project_detail_page.dart';
import '../../models/project.dart';
import '../../controllers/projects_controller.dart';
import '../../controllers/team_controller.dart';
import '../../controllers/export_controller.dart';
import '../../components/project_statistics_card.dart';
import '../../components/employee_performance_card.dart';
import '../../services/project_membership_service.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<EmployeeDashboard> {
  late final ProjectsController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _sortKey = 'started';
  bool _ascending = false;
  final Set<String> _selectedStatuses = {};
  int _currentPage = 1;
  final int _itemsPerPage = 12;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ProjectsController>();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  List<Project> get _visibleProjects {
    List<Project> list = _ctrl.projects.toList();

    // Apply status filter (empty means show all)
    if (_selectedStatuses.isNotEmpty) {
      list = list.where((p) => _selectedStatuses.contains(p.status)).toList();
    } // Apply search filter
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
        case 'defectRate':
          final aRate = a.overallDefectRate ?? 0.0;
          final bRate = b.overallDefectRate ?? 0.0;
          res = aRate.compareTo(bRate);
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

  Widget _buildFilterChip(String status) {
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        double responsiveFontSize(double baseFontSize) =>
            screenWidth * (baseFontSize / 1920) + 8;
        double responsivePadding(double basePadding) =>
            screenWidth * (basePadding / 1920);

        final isSelected = _selectedStatuses.contains(status);
        return FilterChip(
          label: Text(
            status,
            style: TextStyle(fontSize: responsiveFontSize(5)),
          ),
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
            fontSize: responsiveFontSize(5),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: responsivePadding(8),
            vertical: responsivePadding(4),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing helpers
    double responsiveWidth(double baseWidth) =>
        screenWidth * (baseWidth / 1920);
    double responsiveHeight(double baseHeight) =>
        screenHeight * (baseHeight / 1080);
    double responsiveFontSize(double baseFontSize) =>
        screenWidth * (baseFontSize / 1920) + 8;
    double responsivePadding(double basePadding) =>
        screenWidth * (basePadding / 1920);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(responsivePadding(24.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: responsiveFontSize(16),
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsivePadding(16)),
              // Project Statistics and Performance in same row
              Row(
                children: [
                  Expanded(flex: 3, child: const ProjectStatisticsCard()),
                  SizedBox(width: responsivePadding(16)),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance as',
                            style: TextStyle(
                              fontSize: responsiveFontSize(6),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: responsivePadding(12)),
                          const EmployeePerformanceCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsivePadding(16)),
              // Search bar
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: responsiveWidth(1400)),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(responsivePadding(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: responsivePadding(4),
                        offset: Offset(0, responsivePadding(2)),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText:
                          'Search by title, status, priority, created by...',
                      hintStyle: TextStyle(fontSize: responsiveFontSize(6)),
                      prefixIcon: Icon(
                        Icons.search,
                        size: responsiveFontSize(9),
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: responsivePadding(12),
                        vertical: responsivePadding(14),
                      ),
                    ),
                    style: TextStyle(fontSize: responsiveFontSize(6)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              SizedBox(height: responsivePadding(16)),
              // Status filter chips and Export button
              Row(
                children: [
                  Text(
                    'Filter by Status:',
                    style: TextStyle(
                      fontSize: responsiveFontSize(6),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: responsivePadding(12)),
                  _buildFilterChip('Not Started'),
                  SizedBox(width: responsivePadding(8)),
                  _buildFilterChip('In Progress'),
                  SizedBox(width: responsivePadding(8)),
                  _buildFilterChip('Completed'),
                  const Spacer(),
                  // Export Master Excel Button
                  Obx(() {
                    final exportCtrl = Get.find<ExportController>();
                    return ElevatedButton.icon(
                      onPressed: exportCtrl.isExporting.value
                          ? null
                          : () async {
                              await exportCtrl.exportMasterExcel();
                            },
                      icon: exportCtrl.isExporting.value
                          ? SizedBox(
                              width: responsiveFontSize(8),
                              height: responsiveFontSize(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(Icons.download, size: responsiveFontSize(8)),
                      label: Text(
                        exportCtrl.isExporting.value
                            ? 'Exporting...'
                            : 'Export Master Excel',
                        style: TextStyle(fontSize: responsiveFontSize(6)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: EdgeInsets.symmetric(
                          horizontal: responsivePadding(16),
                          vertical: responsivePadding(12),
                        ),
                      ),
                    );
                  }),
                  SizedBox(width: responsivePadding(8)),
                  if (_selectedStatuses.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedStatuses.clear();
                        });
                      },
                      icon: Icon(Icons.clear, size: responsiveFontSize(7)),
                      label: Text(
                        'Clear Filters',
                        style: TextStyle(fontSize: responsiveFontSize(6)),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                ],
              ),
              SizedBox(height: responsivePadding(16)),
              // Tabular layout using ListView + Rows
              Obx(() {
                final allProjects = _visibleProjects;
                final totalProjects = allProjects.length;
                final totalPages = (totalProjects / _itemsPerPage).ceil();

                // Ensure current page is valid
                if (_currentPage > totalPages && totalPages > 0) {
                  _currentPage = totalPages;
                }
                if (_currentPage < 1) {
                  _currentPage = 1;
                }

                // Calculate pagination range
                final startIndex = (_currentPage - 1) * _itemsPerPage;
                final endIndex = (startIndex + _itemsPerPage).clamp(
                  0,
                  totalProjects,
                );
                final projects = allProjects.sublist(
                  startIndex.clamp(0, totalProjects),
                  endIndex,
                );

                return Column(
                  children: [
                    // Pagination controls at top left
                    _buildPaginationControls(
                      totalProjects,
                      startIndex,
                      endIndex,
                      totalPages,
                      context,
                    ),
                    SizedBox(height: responsivePadding(12)),
                    // Single horizontal scrollbar wrapping the entire table
                    Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: false,
                      thickness: responsivePadding(10.0),
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          children: [
                            // Header row
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: responsivePadding(12),
                                horizontal: responsivePadding(16),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  responsivePadding(6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: responsivePadding(4),
                                    offset: Offset(0, responsivePadding(2)),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: responsiveWidth(200),
                                    child: Text(
                                      'Project No.',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey,
                                        fontSize: responsiveFontSize(5),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(300),
                                    child: Text(
                                      'Project Title',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey,
                                        fontSize: responsiveFontSize(5),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(150),
                                    child: Text(
                                      'Team Leader',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey,
                                        fontSize: responsiveFontSize(5),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(180),
                                    child: Text(
                                      'Executors',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey,
                                        fontSize: responsiveFontSize(5),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(180),
                                    child: Text(
                                      'Reviewers',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey,
                                        fontSize: responsiveFontSize(5),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(120),
                                    child: _HeaderCell(
                                      label: 'Defect Rate',
                                      active: _sortKey == 'defectRate',
                                      ascending: _ascending,
                                      onTap: () => _toggleSort('defectRate'),
                                      fontSize: responsiveFontSize(5),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(120),
                                    child: _HeaderCell(
                                      label: 'Started',
                                      active: _sortKey == 'started',
                                      ascending: _ascending,
                                      onTap: () => _toggleSort('started'),
                                      fontSize: responsiveFontSize(5),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(120),
                                    child: _HeaderCell(
                                      label: 'Priority',
                                      active: _sortKey == 'priority',
                                      ascending: _ascending,
                                      onTap: () => _toggleSort('priority'),
                                      fontSize: responsiveFontSize(5),
                                    ),
                                  ),
                                  SizedBox(
                                    width: responsiveWidth(120),
                                    child: _HeaderCell(
                                      label: 'Status',
                                      active: _sortKey == 'status',
                                      ascending: _ascending,
                                      onTap: () => _toggleSort('status'),
                                      fontSize: responsiveFontSize(5),
                                    ),
                                  ),
                                  // Actions column removed (moved to details page)
                                ],
                              ),
                            ),
                            SizedBox(height: responsivePadding(8)),
                            // Project rows without individual scrollbars
                            ...projects
                                .map(
                                  (proj) => _EmployeeProjectCard(
                                    key: ValueKey(proj.id),
                                    project: proj,
                                    context: context,
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
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

  // Description now lives on Project model; no temp store needed.

  Widget _buildPaginationControls(
    int total,
    int start,
    int end,
    int totalPages,
    BuildContext context,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    double responsiveFontSize(double baseFontSize) =>
        screenWidth * (baseFontSize / 1920) + 8;
    double responsivePadding(double basePadding) =>
        screenWidth * (basePadding / 1920);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          total > 0 ? '${start + 1}-$end of $total' : '0 of 0',
          style: TextStyle(
            fontSize: responsiveFontSize(8),
            color: Colors.black87,
          ),
        ),
        SizedBox(width: responsivePadding(16)),
        IconButton(
          icon: Icon(Icons.chevron_left, size: responsiveFontSize(9)),
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
          tooltip: 'Previous',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        SizedBox(width: responsivePadding(8)),
        IconButton(
          icon: Icon(Icons.chevron_right, size: responsiveFontSize(9)),
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          tooltip: 'Next',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _EmployeeProjectCard extends StatelessWidget {
  final Project project;
  final BuildContext context;

  const _EmployeeProjectCard({
    required Key key,
    required this.project,
    required this.context,
  }) : super(key: key);

  Widget _priorityChip(String p) {
    final screenWidth = MediaQuery.of(context).size.width;
    double responsiveFontSize(double baseFontSize) =>
        screenWidth * (baseFontSize / 1920) + 8;

    Color bg = const Color(0xFFEFF3F7);
    if (p == 'High') bg = const Color(0xFFFBEFEF);
    if (p == 'Low') bg = const Color(0xFFF5F7FA);
    return Chip(
      label: Text(p, style: TextStyle(fontSize: responsiveFontSize(4))),
      backgroundColor: bg,
    );
  }

  @override
  Widget build(BuildContext buildContext) {
    final screenWidth = MediaQuery.of(context).size.width;
    double responsiveWidth(double baseWidth) =>
        screenWidth * (baseWidth / 1920);
    double responsiveFontSize(double baseFontSize) =>
        screenWidth * (baseFontSize / 1920) + 8;
    double responsivePadding(double basePadding) =>
        screenWidth * (basePadding / 1920);

    final projCtrl = Get.find<ProjectsController>();

    final executor =
        (project.status == 'In Progress' || project.status == 'Completed')
        ? ((project.executor?.trim().isNotEmpty ?? false)
              ? project.executor!.trim()
              : '--')
        : '--';

    return InkWell(
      onTap: () => Get.to(
        () => EmployeeProjectDetailPage(
          project: project,
          description: project.description,
        ),
      ),
      hoverColor: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(responsivePadding(6)),
      child: Container(
        margin: EdgeInsets.only(bottom: responsivePadding(6)),
        padding: EdgeInsets.symmetric(
          vertical: responsivePadding(10),
          horizontal: responsivePadding(16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(responsivePadding(6)),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Obx(() {
          final cache = projCtrl.membershipCache[project.id];
          final teamLeaders = cache?.teamLeaders ?? [];
          final executors = cache?.executors ?? [];
          final reviewers = cache?.reviewers ?? [];

          return Row(
            children: [
              SizedBox(
                width: responsiveWidth(200),
                child: Text(
                  (project.projectNo?.trim().isNotEmpty ?? false)
                      ? project.projectNo!.trim()
                      : '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: responsiveFontSize(5)),
                ),
              ),
              SizedBox(
                width: responsiveWidth(300),
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: responsiveFontSize(5)),
                ),
              ),
              SizedBox(
                width: responsiveWidth(150),
                child: Text(
                  teamLeaders.isEmpty ? '--' : teamLeaders.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: responsiveFontSize(5)),
                ),
              ),
              SizedBox(
                width: responsiveWidth(180),
                child: Text(
                  executors.isEmpty ? '--' : executors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: responsiveFontSize(5)),
                ),
              ),
              SizedBox(
                width: responsiveWidth(180),
                child: Text(
                  reviewers.isEmpty ? '--' : reviewers.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: responsiveFontSize(5)),
                ),
              ),
              SizedBox(
                width: responsiveWidth(120),
                child: Text(
                  project.overallDefectRate != null
                      ? '${project.overallDefectRate!.toStringAsFixed(1)}%'
                      : '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsiveFontSize(5),
                    color: project.overallDefectRate != null
                        ? Colors.red
                        : Colors.black87,
                    fontWeight: project.overallDefectRate != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              SizedBox(
                width: responsiveWidth(120),
                child: Text(
                  '${project.started.year}-${project.started.month.toString().padLeft(2, '0')}-${project.started.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: responsiveFontSize(5)),
                ),
              ),
              SizedBox(
                width: responsiveWidth(120),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _priorityChip(project.priority),
                ),
              ),
              SizedBox(
                width: responsiveWidth(120),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (project.status).toString(),
                    style: TextStyle(fontSize: responsiveFontSize(5)),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
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
  final void Function(ProjectFormData data) onSubmit;

  const _ProjectFormDialog({required this.title, required this.onSubmit});

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late ProjectFormData data;

  @override
  void initState() {
    super.initState();
    data = ProjectFormData(
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
        width: 520,
        height: 600,
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
                    // Always single column layout. Place Description at the top.
                    final List<Widget> fields = [
                      // Large description area at top
                      // Description

                      // Title
                      TextFormField(
                        initialValue: data.title,
                        decoration: const InputDecoration(
                          labelText: 'Project Title *',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter title';
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
                          if (picked != null) {
                            setState(() => data.started = picked);
                          }
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
                    ];
                    fields.add(
                      DropdownButtonFormField<String>(
                        initialValue: data.status,
                        items: ['In Progress', 'Completed', 'Not Started']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => data.status = v ?? data.status),
                        decoration: const InputDecoration(
                          labelText: 'Status *',
                        ),
                      ),
                    );
                    fields.add(
                      DropdownButtonFormField<String>(
                        initialValue: (data.executor?.isEmpty ?? true)
                            ? null
                            : data.executor,
                        items:
                            (Get.isRegistered<TeamController>()
                                    ? Get.find<TeamController>().members
                                          .map((m) => m.name.trim())
                                          .where((n) => n.isNotEmpty)
                                          .toSet()
                                          .toList()
                                    : const <String>[])
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

                    return Column(
                      children: [
                        for (int i = 0; i < fields.length; i++) ...[
                          fields[i],
                          if (i != fields.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
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
                  initialValue: data.description,
                  minLines: 10,
                  maxLines: 16,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Enter description...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter description'
                      : null,
                  onSaved: (v) => data.description = v!.trim(),
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
                      child: const Text('Create'),
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
  final double fontSize;

  const _HeaderCell({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    required this.fontSize,
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
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: fontSize,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 4),
          Icon(icon, size: fontSize + 3, color: color),
        ],
      ),
    );
  }
}
