/// Page wrapper for ProjectChecklistExecutionWidget.
/// This page handles navigation and data passing for the execution-mode checklist.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/stage_service.dart';
import '../../widgets/project_checklist_execution_widget.dart';

class ProjectChecklistExecutionPage extends StatefulWidget {
  final String projectId;
  final String stageId; // Can be empty - will be fetched if needed
  final String stageName;
  final String projectTitle;
  final List<String> executors;
  final List<String> reviewers;
  final List<String> leaders;

  const ProjectChecklistExecutionPage({
    super.key,
    required this.projectId,
    required this.stageId,
    required this.stageName,
    required this.projectTitle,
    required this.executors,
    required this.reviewers,
    required this.leaders,
  });

  @override
  State<ProjectChecklistExecutionPage> createState() =>
      _ProjectChecklistExecutionPageState();
}

class _ProjectChecklistExecutionPageState
    extends State<ProjectChecklistExecutionPage> {
  String? _resolvedStageId;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveStageId();
  }

  Future<void> _resolveStageId() async {
    try {
      // If stageId provided, use it directly
      if (widget.stageId.isNotEmpty) {
        setState(() {
          _resolvedStageId = widget.stageId;
          _isLoading = false;
        });
        return;
      }

      // Otherwise, fetch stages and find matching phase
      final stageService = Get.find<StageService>();
      final stages = await stageService.listStages(widget.projectId);
      
      // Extract phase number from stageName (e.g., "Phase 1" -> 1)
      final phaseMatch = RegExp(r'Phase (\d+)').firstMatch(widget.stageName);
      if (phaseMatch == null) {
        throw Exception('Could not parse phase from: ${widget.stageName}');
      }
      final phaseNum = int.parse(phaseMatch.group(1)!);
      
      // Find stage for this phase
      final stage = stages.firstWhereOrNull((s) {
        final stageName = (s['stage_name'] ?? '').toString().toLowerCase();
        return stageName.contains('phase $phaseNum');
      });

      if (stage == null) {
        throw Exception('No stage found for ${widget.stageName}');
      }

      setState(() {
        _resolvedStageId = (stage['_id'] ?? '').toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stage: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.stageName} - ${widget.projectTitle}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Get.back(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : _resolvedStageId != null
                  ? ProjectChecklistExecutionWidget(
                      projectId: widget.projectId,
                      stageId: _resolvedStageId!,
                      stageName: widget.stageName,
                      executors: widget.executors,
                      reviewers: widget.reviewers,
                      leaders: widget.leaders,
                    )
                  : const Center(child: Text('Could not resolve stage')),
    );
  }
}
