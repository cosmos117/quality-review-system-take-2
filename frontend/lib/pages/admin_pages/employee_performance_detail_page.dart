import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/projects_controller.dart';
import '../../models/team_member.dart';
import '../../models/project.dart';
import '../../services/project_membership_service.dart';
import '../../components/shimmer_loading.dart';

class EmployeePerformanceDetailPage extends StatefulWidget {
  final TeamMember member;
  const EmployeePerformanceDetailPage({super.key, required this.member});

  @override
  State<EmployeePerformanceDetailPage> createState() =>
      _EmployeePerformanceDetailPageState();
}

class _EmployeePerformanceDetailPageState
    extends State<EmployeePerformanceDetailPage> {
  bool _isLoading = true;
  List<Project> _current = [];
  List<Project> _completed = [];
  Map<String, List<String>> _projectRoles = {};
  List<Project> _leaderProjects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final projectsCtrl = Get.find<ProjectsController>();
      final membershipService = Get.find<ProjectMembershipService>();

      // Refresh all projects first
      await projectsCtrl.refreshProjects();

      if (!mounted) return;

      // Get all projects for this employee through their memberships
      final userProjectsData = await membershipService.getUserProjects(
        widget.member.id,
      );

      // Extract project IDs from membership data
      // Each element is a ProjectMembership with a populated project_id field
      final employeeProjectIds = <String>{};
      for (final membership in userProjectsData) {
        final projectId = membership['project_id'];
        if (projectId is Map) {
          final id = projectId['_id'] ?? projectId['id'];
          if (id != null) {
            employeeProjectIds.add(id.toString());
          }
        } else if (projectId != null) {
          employeeProjectIds.add(projectId.toString());
        }
      }

      // Get the actual project objects
      final allProjects = projectsCtrl.projects
          .where((p) => employeeProjectIds.contains(p.id))
          .toList();

      // Separate into current and completed
      bool isCompleted(Project p) => p.status.toLowerCase() == 'completed';

      // Fetch roles for each project
      final rolesMap = <String, List<String>>{};
      final leaderProjects = <Project>[];

      for (final project in allProjects) {
        try {
          final memberships = await membershipService.getProjectMembers(
            project.id,
          );
          final userRoles = memberships
              .where((m) => m.userId == widget.member.id)
              .map((m) => m.roleName ?? 'Unknown')
              .toList();
          rolesMap[project.id] = userRoles;

          // Check if user is team leader in this project
          final isTeamLeader = userRoles.any(
            (role) => role.toLowerCase().contains('teamleader'),
          );
          if (isTeamLeader) {
            leaderProjects.add(project);
          }
        } catch (e) {
          rolesMap[project.id] = [];
        }
      }

      if (mounted) {
        setState(() {
          _current = allProjects.where((p) => !isCompleted(p)).toList();
          _completed = allProjects.where(isCompleted).toList();
          _projectRoles = rolesMap;
          _leaderProjects = leaderProjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _current = [];
          _completed = [];
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load projects: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadProjects,
            ),
          ),
        );
      }
    }
  }

  double _calculateOverallLeaderPerformance() {
    if (_leaderProjects.isEmpty) return 0.0;

    double totalDefectRate = 0.0;
    int projectsWithDefectRate = 0;

    for (final project in _leaderProjects) {
      if (project.overallDefectRate != null) {
        totalDefectRate += project.overallDefectRate!;
        projectsWithDefectRate++;
      }
    }

    if (projectsWithDefectRate == 0) return 0.0;
    return totalDefectRate / projectsWithDefectRate;
  }

  Color _getPerformanceColor(double performance) {
    if (performance <= 5.0) return Colors.green;
    if (performance <= 20.0) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceLabel(double performance) {
    if (performance <= 5.0) return 'Excellent';
    if (performance <= 20.0) return 'Good';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    final overallLeaderPerformance = _calculateOverallLeaderPerformance();
    final hasLeaderProjects = _leaderProjects.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadProjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: SkeletonTable(rowCount: 5, columns: 5),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left side: Title and project count
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Projects for ${widget.member.name}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'TOTAL: ${_current.length + _completed.length} PROJECTS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Right side: Team Leader Performance box if applicable
                      if (hasLeaderProjects)
                        SizedBox(
                          width: 650,
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: _getPerformanceColor(overallLeaderPerformance),
                                    size: 38,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Team Leader Performance',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '${overallLeaderPerformance.toStringAsFixed(2)}%',
                                              style: TextStyle(
                                                fontSize: 44,
                                                fontWeight: FontWeight.bold,
                                                color: _getPerformanceColor(overallLeaderPerformance),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Overall Defect Rate',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.assignment_outlined,
                                          size: 32,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_leaderProjects.length}',
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              'as Leader',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.blue.shade900,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Projects Section
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _ProjectListSection(
                                    title: 'Current Projects',
                                    projects: _current,
                                    projectRoles: _projectRoles,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _ProjectListSection(
                                    title: 'Completed Projects',
                                    projects: _completed,
                                    projectRoles: _projectRoles,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ProjectListSection(
                                  title: 'Current Projects',
                                  projects: _current,
                                  projectRoles: _projectRoles,
                                ),
                                const SizedBox(height: 24),
                                _ProjectListSection(
                                  title: 'Completed Projects',
                                  projects: _completed,
                                  projectRoles: _projectRoles,
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProjectListSection extends StatelessWidget {
  final String title;
  final List<Project> projects;
  final Map<String, List<String>> projectRoles;

  const _ProjectListSection({
    required this.title,
    required this.projects,
    required this.projectRoles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${projects.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No projects',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ...List.generate(
            projects.length,
            (i) => _ProjectCard(
              project: projects[i],
              roles: projectRoles[projects[i].id] ?? [],
            ),
          ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<String> roles;

  const _ProjectCard({required this.project, required this.roles});

  Color _getDefectRateColor(double? rate) {
    if (rate == null) return Colors.grey.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(project.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    project.status,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: roles
                    .map(
                      (role) => Chip(
                        label: Text(role, style: const TextStyle(fontSize: 13)),
                        backgroundColor: const Color(0xFFEFF3F7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Started: ${project.started.year}-${project.started.month.toString().padLeft(2, '0')}-${project.started.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (project.overallDefectRate != null) ...[
                  const Icon(Icons.bug_report, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Defect Rate: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    '${project.overallDefectRate!.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _getDefectRateColor(project.overallDefectRate),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'on hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
