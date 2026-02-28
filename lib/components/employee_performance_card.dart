import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/projects_controller.dart';

class EmployeePerformanceCard extends StatefulWidget {
  const EmployeePerformanceCard({super.key});

  @override
  State<EmployeePerformanceCard> createState() =>
      _EmployeePerformanceCardState();
}

class _EmployeePerformanceCardState extends State<EmployeePerformanceCard> {
  double _executorAvg = 0.0;
  double _leaderAvg = 0.0;
  Timer? _debounceTimer;
  Worker? _projectsWorker;

  @override
  void initState() {
    super.initState();
    _setupListener();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _projectsWorker?.dispose();
    super.dispose();
  }

  void _setupListener() {
    final projCtrl = Get.find<ProjectsController>();

    // Listen to projects changes with debounce
    _projectsWorker = ever(projCtrl.projects, (_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _updatePerformanceMetrics();
      });
    });

    // Initial load
    _updatePerformanceMetrics();
  }

  void _updatePerformanceMetrics() {
    final projCtrl = Get.find<ProjectsController>();

    // Only update if we have projects with userRole data
    final projectsWithRoles = projCtrl.projects
        .where((p) => p.userRole != null)
        .toList();

    if (projectsWithRoles.isEmpty) return;

    // Filter projects by user role
    final executorProjects = projectsWithRoles
        .where((p) => p.userRole!.toLowerCase().contains('executor'))
        .toList();

    final leaderProjects = projectsWithRoles
        .where((p) => p.userRole!.toLowerCase().contains('teamleader'))
        .toList();

    final executorIds = executorProjects.map((p) => p.id).toList();
    final leaderIds = leaderProjects.map((p) => p.id).toList();

    final newExecutorAvg = _calculateAverageDefectRate(executorIds, projCtrl);
    final newLeaderAvg = _calculateAverageDefectRate(leaderIds, projCtrl);

    // Only update if values changed
    if (_executorAvg != newExecutorAvg || _leaderAvg != newLeaderAvg) {
      if (mounted) {
        setState(() {
          _executorAvg = newExecutorAvg;
          _leaderAvg = newLeaderAvg;
        });
      }
    }
  }

  double _calculateAverageDefectRate(
    List projectIds,
    ProjectsController projCtrl,
  ) {
    // Filter projects by IDs and get those with defect rates
    final projectsWithDefectRates = projCtrl.projects
        .where((p) => projectIds.contains(p.id) && p.overallDefectRate != null)
        .toList();

    if (projectsWithDefectRates.isEmpty) return 0.0;

    final sum = projectsWithDefectRates.fold<double>(
      0.0,
      (prev, p) => prev + (p.overallDefectRate ?? 0.0),
    );

    return sum / projectsWithDefectRates.length;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildPerformanceItem(
          label: 'Executors',
          value: _executorAvg,
          color: Colors.purple,
        ),
        _buildDivider(),
        _buildPerformanceItem(
          label: 'Team Leaders',
          value: _leaderAvg,
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildPerformanceItem({
    required String label,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
