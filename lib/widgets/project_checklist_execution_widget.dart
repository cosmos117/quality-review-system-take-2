/// Hierarchical checklist execution widget for ProjectChecklist structure.
/// This widget handles role-based editing (Executor, Reviewer, SDH) and renders
/// the hierarchical structure: Group → Sections (optional) → Questions.
/// 
/// This is distinct from the template editor (checklist.dart) and is used
/// when displaying a project's execution-mode checklist.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../models/project_checklist.dart';
import '../../services/project_checklist_service.dart';

class ProjectChecklistExecutionWidget extends StatefulWidget {
  final String projectId;
  final String stageId;
  final String stageName;
  final List<String> executors;
  final List<String> reviewers;
  final List<String> leaders; // SDH users
  final bool readOnly; // If true, all controls disabled

  const ProjectChecklistExecutionWidget({
    super.key,
    required this.projectId,
    required this.stageId,
    required this.stageName,
    required this.executors,
    required this.reviewers,
    required this.leaders,
    this.readOnly = false,
  });

  @override
  State<ProjectChecklistExecutionWidget> createState() =>
      _ProjectChecklistExecutionWidgetState();
}

class _ProjectChecklistExecutionWidgetState
    extends State<ProjectChecklistExecutionWidget> {
  late final ProjectChecklistService _checklistService;
  ProjectChecklist? _checklist;
  String? _errorMessage;
  bool _isLoading = true;
  final Set<String> _expandedGroups = {};

  // Role permissions for current user
  late final bool _canEditExecutor;
  late final bool _canEditReviewer;
  late final bool _isSDH;

  @override
  void initState() {
    super.initState();
    _checklistService = Get.find<ProjectChecklistService>();
    _determineRolePermissions();
    _loadChecklist();
  }

  void _determineRolePermissions() {
    String? currentUserName;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      currentUserName = auth.currentUser.value?.name;
    }

    _canEditExecutor = currentUserName != null &&
        widget.executors
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    _canEditReviewer = currentUserName != null &&
        widget.reviewers
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    _isSDH = currentUserName != null &&
        widget.leaders
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());
  }

  Future<void> _loadChecklist() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final checklistData = await _checklistService.fetchChecklist(
        widget.projectId,
        widget.stageId,
      );

      if (mounted) {
        setState(() {
          _checklist = ProjectChecklist.fromJson(checklistData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load checklist: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateExecutorAnswer(
    String groupId,
    String questionId,
    String? answer,
    String? remark,
  ) async {
    try {
      // Update group state from API response
      final updatedGroupJson = await _checklistService.updateExecutor(
        widget.projectId,
        widget.stageId,
        groupId,
        questionId,
        answer: answer,
        remark: remark,
      );

      final updatedGroup = ProjectChecklistGroup.fromJson(updatedGroupJson);

      if (mounted && _checklist != null) {
        setState(() {
          _checklist = _checklist!.updateGroup(updatedGroup);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Executor answer updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateReviewerStatus(
    String groupId,
    String questionId,
    String? status,
    String? remark,
  ) async {
    try {
      // Update group state from API response
      final updatedGroupJson = await _checklistService.updateReviewer(
        widget.projectId,
        widget.stageId,
        groupId,
        questionId,
        status: status,
        remark: remark,
      );

      final updatedGroup = ProjectChecklistGroup.fromJson(updatedGroupJson);

      if (mounted && _checklist != null) {
        setState(() {
          _checklist = _checklist!.updateGroup(updatedGroup);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reviewer status updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChecklist,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_checklist == null || _checklist!.groups.isEmpty) {
      return const Center(
        child: Text('No checklist items found'),
      );
    }

    return ListView.builder(
      itemCount: _checklist!.groups.length,
      itemBuilder: (context, index) {
        final group = _checklist!.groups[index];
        final isExpanded = _expandedGroups.contains(group.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ExpansionTile(
            title: Text(
              group.groupName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedGroups.add(group.id);
                } else {
                  _expandedGroups.remove(group.id);
                }
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Direct questions in group
                    ...group.questions.map((question) {
                      return _QuestionTile(
                        question: question,
                        groupId: group.id,
                        onExecutorUpdate: (answer, remark) =>
                            _updateExecutorAnswer(
                          group.id,
                          question.id,
                          answer,
                          remark,
                        ),
                        onReviewerUpdate: (status, remark) =>
                            _updateReviewerStatus(
                          group.id,
                          question.id,
                          status,
                          remark,
                        ),
                        canEditExecutor:
                            !widget.readOnly && _canEditExecutor,
                        canEditReviewer:
                            !widget.readOnly && _canEditReviewer,
                        isSDH: _isSDH,
                      );
                    }).toList(),

                    // Sections with their questions
                    ...group.sections.map((section) {
                      return _SectionTile(
                        section: section,
                        groupId: group.id,
                        onExecutorUpdate: (questionId, answer, remark) =>
                            _updateExecutorAnswer(
                          group.id,
                          questionId,
                          answer,
                          remark,
                        ),
                        onReviewerUpdate: (questionId, status, remark) =>
                            _updateReviewerStatus(
                          group.id,
                          questionId,
                          status,
                          remark,
                        ),
                        canEditExecutor:
                            !widget.readOnly && _canEditExecutor,
                        canEditReviewer:
                            !widget.readOnly && _canEditReviewer,
                        isSDH: _isSDH,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Displays a single question with executor and reviewer controls
class _QuestionTile extends StatefulWidget {
  final ProjectQuestion question;
  final String groupId;
  final Function(String?, String?) onExecutorUpdate;
  final Function(String?, String?) onReviewerUpdate;
  final bool canEditExecutor;
  final bool canEditReviewer;
  final bool isSDH;

  const _QuestionTile({
    required this.question,
    required this.groupId,
    required this.onExecutorUpdate,
    required this.onReviewerUpdate,
    required this.canEditExecutor,
    required this.canEditReviewer,
    required this.isSDH,
  });

  @override
  State<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<_QuestionTile> {
  late TextEditingController _executorRemarkCtrl;
  late TextEditingController _reviewerRemarkCtrl;
  bool _showExecutorForm = false;
  bool _showReviewerForm = false;

  @override
  void initState() {
    super.initState();
    _executorRemarkCtrl =
        TextEditingController(text: widget.question.executorRemark ?? '');
    _reviewerRemarkCtrl =
        TextEditingController(text: widget.question.reviewerRemark ?? '');
  }

  @override
  void dispose() {
    _executorRemarkCtrl.dispose();
    _reviewerRemarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            widget.question.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),

          // Executor section
          if (widget.canEditExecutor || widget.question.executorAnswer != null)
            _buildExecutorSection(),
          if ((widget.canEditExecutor || widget.question.executorAnswer != null) &&
              (widget.canEditReviewer || widget.question.reviewerStatus != null))
            const Divider(),

          // Reviewer section
          if (widget.canEditReviewer || widget.question.reviewerStatus != null)
            _buildReviewerSection(),
        ],
      ),
    );
  }

  Widget _buildExecutorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Executor Answer:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.canEditExecutor)
          Column(
            children: [
              // Answer dropdown
              DropdownButton<String?>(
                value: widget.question.executorAnswer,
                items: [null, 'Yes', 'No', 'NA']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value ?? 'Not Answered'),
                        ))
                    .toList(),
                onChanged: (value) async {
                  _executorRemarkCtrl.clear();
                  _showExecutorForm = false;
                  await widget.onExecutorUpdate(value, null);
                },
              ),
              const SizedBox(height: 8),
              // Remark text field
              if (_showExecutorForm || widget.question.executorRemark != null)
                TextField(
                  controller: _executorRemarkCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add remark...',
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  maxLines: 2,
                  onChanged: (remark) {
                    // Debounce updates or use a save button
                  },
                ),
              if (!_showExecutorForm && widget.question.executorAnswer != null)
                TextButton(
                  onPressed: () {
                    setState(() => _showExecutorForm = true);
                  },
                  child: const Text('Add/Edit Remark'),
                ),
              if (_showExecutorForm)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await widget.onExecutorUpdate(
                          widget.question.executorAnswer,
                          _executorRemarkCtrl.text,
                        );
                        setState(() => _showExecutorForm = false);
                      },
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _executorRemarkCtrl.text =
                            widget.question.executorRemark ?? '';
                        setState(() => _showExecutorForm = false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          )
        else
          // Read-only display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.executorAnswer ?? 'Not Answered',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (widget.question.executorRemark != null &&
                  widget.question.executorRemark!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Remark: ${widget.question.executorRemark}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildReviewerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviewer Status:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.canEditReviewer)
          Column(
            children: [
              // Status dropdown
              DropdownButton<String?>(
                value: widget.question.reviewerStatus,
                items: [null, 'Approved', 'Rejected']
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value ?? 'Not Reviewed'),
                        ))
                    .toList(),
                onChanged: (value) async {
                  _reviewerRemarkCtrl.clear();
                  _showReviewerForm = false;
                  await widget.onReviewerUpdate(value, null);
                },
              ),
              const SizedBox(height: 8),
              // Remark text field
              if (_showReviewerForm || widget.question.reviewerRemark != null)
                TextField(
                  controller: _reviewerRemarkCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add review remark...',
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  maxLines: 2,
                  onChanged: (remark) {
                    // Debounce updates or use a save button
                  },
                ),
              if (!_showReviewerForm && widget.question.reviewerStatus != null)
                TextButton(
                  onPressed: () {
                    setState(() => _showReviewerForm = true);
                  },
                  child: const Text('Add/Edit Remark'),
                ),
              if (_showReviewerForm)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await widget.onReviewerUpdate(
                          widget.question.reviewerStatus,
                          _reviewerRemarkCtrl.text,
                        );
                        setState(() => _showReviewerForm = false);
                      },
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _reviewerRemarkCtrl.text =
                            widget.question.reviewerRemark ?? '';
                        setState(() => _showReviewerForm = false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          )
        else
          // Read-only display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.reviewerStatus ?? 'Not Reviewed',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (widget.question.reviewerRemark != null &&
                  widget.question.reviewerRemark!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Remark: ${widget.question.reviewerRemark}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Displays a section with its questions
class _SectionTile extends StatelessWidget {
  final ProjectSection section;
  final String groupId;
  final Function(String, String?, String?) onExecutorUpdate;
  final Function(String, String?, String?) onReviewerUpdate;
  final bool canEditExecutor;
  final bool canEditReviewer;
  final bool isSDH;

  const _SectionTile({
    required this.section,
    required this.groupId,
    required this.onExecutorUpdate,
    required this.onReviewerUpdate,
    required this.canEditExecutor,
    required this.canEditReviewer,
    required this.isSDH,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              section.sectionName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: section.questions
                  .map(
                    (question) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuestionTile(
                        question: question,
                        groupId: groupId,
                        onExecutorUpdate: (answer, remark) =>
                            onExecutorUpdate(question.id, answer, remark),
                        onReviewerUpdate: (status, remark) =>
                            onReviewerUpdate(question.id, status, remark),
                        canEditExecutor: canEditExecutor,
                        canEditReviewer: canEditReviewer,
                        isSDH: isSDH,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
