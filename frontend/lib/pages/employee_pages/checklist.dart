import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:url_launcher/url_launcher.dart';
import 'checklist_controller.dart';
import '../../services/phase_checklist_service.dart';
import '../../services/iteration_service.dart';
import '../../controllers/auth_controller.dart';

import '../../config/api_config.dart';

// Backend base URL for uploads; uses ApiConfig as single source of truth
String get _imageBaseUrl => ApiConfig.baseUrl;

enum UploadStatus { pending, uploading, success, failed }

class ImageUploadState {
  UploadStatus status;
  double progress;
  Object? cancelToken; // keep flexible to avoid hard dependency
  ImageUploadState({
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.cancelToken,
  });
}

class Question {
  final String mainQuestion;
  // Each sub-question keeps its backend id (if any) and display text.
  // { 'id': '<checkpointId>', 'text': '<question text>', 'categoryId': '<optional>', 'sectionName': '<optional>' }
  final List<Map<String, String>> subQuestions;
  final String? checklistId; // MongoDB ID for backend checklist or group
  final int defectCount; // Number of defects for this group

  Question({
    required this.mainQuestion,
    required this.subQuestions,
    this.checklistId,
    this.defectCount = 0,
  });

  static List<Question> fromChecklist(
    Map<String, dynamic> checklist,
    List<Map<String, dynamic>> checkpoints,
  ) {
    final checklistId = (checklist['_id'] ?? '').toString();
    final checklistName = (checklist['checklist_name'] ?? '').toString();

    final checkpointObjs = checkpoints
        .map(
          (cp) => {
            'id': (cp['_id'] ?? '').toString(),
            'text': (cp['question'] ?? '').toString(),
            'categoryId': (cp['categoryId'] ?? '').toString(),
          },
        )
        .where((m) => (m['text'] ?? '').isNotEmpty)
        .cast<Map<String, String>>()
        .toList();

    return [
      Question(
        mainQuestion: checklistName,
        subQuestions: checkpointObjs,
        checklistId: checklistId,
      ),
    ];
  }

  // New: Create from hierarchical ProjectChecklist group structure
  static List<Question> fromProjectChecklistGroups(List<dynamic> groups) {
    final questions = <Question>[];

    for (final group in groups) {
      if (group is! Map<String, dynamic>) continue;

      final groupId = (group['_id'] ?? '').toString();
      final groupName = (group['groupName'] ?? '').toString();
      final defectCount = (group['currentDefects'] ?? 0) as int;
      final subQuestions = <Map<String, String>>[];

      // Add direct questions in group
      final directQuestions = group['questions'] as List<dynamic>? ?? [];
      for (final q in directQuestions) {
        if (q is! Map<String, dynamic>) continue;
        subQuestions.add({
          'id': (q['_id'] ?? '').toString(),
          'text': (q['text'] ?? '').toString(),
          'categoryId': '', // Can be added later if needed
        });
      }

      // Add questions from sections
      final sections = group['sections'] as List<dynamic>? ?? [];
      for (final section in sections) {
        if (section is! Map<String, dynamic>) continue;
        final sectionName = (section['sectionName'] ?? '').toString();
        final sectionQuestions = section['questions'] as List<dynamic>? ?? [];
        for (final q in sectionQuestions) {
          if (q is! Map<String, dynamic>) continue;
          subQuestions.add({
            'id': (q['_id'] ?? '').toString(),
            'text': (q['text'] ?? '').toString(),
            'categoryId': '', // Can be added later if needed
            'sectionName': sectionName,
          });
        }
      }

      if (subQuestions.isNotEmpty) {
        questions.add(
          Question(
            mainQuestion: groupName,
            subQuestions: subQuestions,
            checklistId: groupId,
            defectCount: defectCount,
          ),
        );
      }
    }

    return questions;
  }
}

class _AddCheckpointRow extends StatefulWidget {
  final String? checklistId;
  final Future<void> Function()? onAdded;
  const _AddCheckpointRow({this.checklistId, this.onAdded});

  @override
  State<_AddCheckpointRow> createState() => _AddCheckpointRowState();
}

class _AddCheckpointRowState extends State<_AddCheckpointRow> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'New checkpoint question',
            ),
            onSubmitted: (_) => _add(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _add,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || widget.checklistId == null) return;
    setState(() => _loading = true);
    try {
      final svc = Get.find<PhaseChecklistService>();
      await svc.createCheckpoint(widget.checklistId!, question: txt);
      _ctrl.clear();
      if (widget.onAdded != null) await widget.onAdded!();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EditableCheckpointTile extends StatefulWidget {
  final String initialText;
  final String? checkpointId;
  final String? checklistId;
  final Future<void> Function()? onSaved;
  const _EditableCheckpointTile({
    required this.initialText,
    this.checkpointId,
    this.checklistId,
    this.onSaved,
  });

  @override
  State<_EditableCheckpointTile> createState() =>
      _EditableCheckpointTileState();
}

class _EditableCheckpointTileState extends State<_EditableCheckpointTile> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          onPressed: _loading ? null : _save,
        ),
      ),
      onSubmitted: (_) => _save(),
    );
  }

  Future<void> _save() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    setState(() => _loading = true);
    try {
      final svc = Get.find<PhaseChecklistService>();
      if (widget.checkpointId != null && widget.checkpointId!.isNotEmpty) {
        await svc.updateCheckpoint(widget.checkpointId!, {'question': txt});
      } else if (widget.checklistId != null && widget.checklistId!.isNotEmpty) {
        await svc.createCheckpoint(widget.checklistId!, question: txt);
      }
      if (widget.onSaved != null) await widget.onSaved!();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class RoleColumn extends StatelessWidget {
  final String role;
  final Color color;
  final String projectId;
  final String? stageId; // Added: for fetching iterations
  final int phase;
  final bool canEdit;
  final List<Question> checklist;
  final Map<String, Map<String, dynamic>> answers;
  final Map<String, Map<String, dynamic>> otherAnswers;
  final Set<int> expanded;
  final ScrollController scrollController;
  final Set<String> highlightSubs;
  final ChecklistController checklistCtrl;
  final Map<String, String?> selectedDefectCategory;
  final Map<String, String?> selectedDefectSeverity;
  final bool editMode;
  final Future<void> Function()? onRefresh;
  final Function(int) onExpand;
  final Function(String, Map<String, dynamic>) onAnswer;
  final Future<void> Function() onSubmit;
  final Future<void> Function()? onRevert; // New: revert callback for reviewer
  final bool isCurrentUserReviewer; // Check if logged-in user is a reviewer
  final Map<String, int>? defectsByChecklist;
  final Map<String, int>? checkpointsByChecklist;
  final bool showDefects;
  final Map<String, dynamic>? Function(String?)? getCategoryInfo;
  final List<Map<String, dynamic>>
  availableCategories; // Added: for category assignment
  final List<dynamic>
  iterations; // Added: shared iteration data to avoid redundant per-card fetches
  final Function(String checkpointId, String? categoryId, {String? severity})?
  onCategoryAssigned; // Added: callback for category assignment

  const RoleColumn({
    required this.role,
    required this.color,
    required this.projectId,
    required this.phase,
    required this.canEdit,
    required this.checklist,
    required this.answers,
    required this.otherAnswers,
    required this.expanded,
    required this.scrollController,
    required this.highlightSubs,
    required this.checklistCtrl,
    required this.selectedDefectCategory,
    required this.selectedDefectSeverity,
    required this.onExpand,
    required this.onAnswer,
    required this.onSubmit,
    this.iterations = const [],
    this.stageId,
    this.onRevert,
    this.isCurrentUserReviewer = false,
    this.editMode = false,
    this.onRefresh,
    this.defectsByChecklist,
    this.checkpointsByChecklist,
    this.showDefects = false,
    this.getCategoryInfo,
    this.availableCategories = const [],
    this.onCategoryAssigned,
  });

  @override
  Widget build(BuildContext context) {
    final title = role == 'executor' ? 'Executor Section' : 'Reviewer Section';
    final bgColor = role == 'executor'
        ? Colors.blue.shade100
        : Colors.green.shade100;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: bgColor,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                if (!canEdit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View only',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          _SubmitBar(
            role: role,
            projectId: projectId,
            phase: phase,
            onSubmit: onSubmit,
            onRevert: onRevert,
            isCurrentUserReviewer: isCurrentUserReviewer,
            submissionInfo: checklistCtrl.submissionInfo(
              projectId,
              phase,
              role,
            ),
            executorSubmissionInfo: role == 'reviewer'
                ? checklistCtrl.submissionInfo(projectId, phase, 'executor')
                : null,
            canEdit: canEdit,
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: checklist.length,
              itemBuilder: (context, index) {
                final q = checklist[index];
                // sub is Map<String,String>
                String subKey(Map<String, String> s) =>
                    (s['id']?.isNotEmpty == true ? s['id'] : s['text'])!;
                String subText(Map<String, String> s) => (s['text'] ?? '');

                // OPTIMIZED: Pre-calculate differs once and cache it
                final differs = _calculateDiffers(
                  q.subQuestions,
                  answers,
                  otherAnswers,
                  checklistCtrl,
                  projectId,
                  phase,
                  role,
                );
                final isExpanded = expanded.contains(index);
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: differs ? Colors.redAccent : color),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: differs ? Colors.red.shade50 : null,
                  child: Column(
                    children: [
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (role == 'executor')
                              _DefectChip(
                                defectCount:
                                    defectsByChecklist?[q.checklistId] ??
                                    q.defectCount,
                                checkpointCount: q.subQuestions.length,
                              ),
                            if (role == 'executor') const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.mainQuestion,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (editMode &&
                                (q.checklistId != null &&
                                    q.checklistId!.isNotEmpty))
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Rename checklist',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final ctrl = TextEditingController(
                                        text: q.mainQuestion,
                                      );
                                      final newName = await showDialog<String?>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Rename checklist'),
                                          content: TextField(controller: ctrl),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Get.back(result: null),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Get.back(
                                                result: ctrl.text.trim(),
                                              ),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (newName != null &&
                                          newName.isNotEmpty) {
                                        try {
                                          final svc =
                                              Get.find<PhaseChecklistService>();
                                          await svc.updateChecklist(
                                            q.checklistId!,
                                            {'checklist_name': newName},
                                          );
                                          if (onRefresh != null) {
                                            await onRefresh!();
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Rename failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete checklist',
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final ok = await showDialog<bool?>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Delete checklist?',
                                          ),
                                          content: const Text(
                                            'This will remove the checklist and its checkpoints for this project.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Get.back(result: false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Get.back(result: true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        try {
                                          final svc =
                                              Get.find<PhaseChecklistService>();
                                          await svc.deleteChecklist(
                                            q.checklistId!,
                                          );
                                          if (onRefresh != null) {
                                            await onRefresh!();
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Delete failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                        onTap: () => onExpand(index),
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // When editing allow adding a checkpoint
                              if (editMode)
                                _AddCheckpointRow(
                                  checklistId: q.checklistId,
                                  onAdded: onRefresh,
                                ),
                              // Track last section for section header display
                              ...() {
                                String? lastSection;
                                return q.subQuestions.map((sub) {
                                  final key = subKey(sub);
                                  final text = subText(sub);
                                  final sectionName = sub['sectionName'];

                                  // DEBUG: Log the key and category lookup
                                  final widgets = <Widget>[];

                                  // Add section header if section changed
                                  if (sectionName != null &&
                                      sectionName != lastSection) {
                                    widgets.add(
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12,
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.folder,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              sectionName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    lastSection = sectionName;
                                  }

                                  // Add the question card
                                  widgets.add(
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (editMode)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      _EditableCheckpointTile(
                                                        initialText: text,
                                                        checkpointId: sub['id'],
                                                        checklistId:
                                                            q.checklistId,
                                                        onSaved: onRefresh,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed:
                                                      sub['id'] != null &&
                                                          sub['id']!.isNotEmpty
                                                      ? () async {
                                                          final confirm = await showDialog<bool?>(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              title: const Text(
                                                                'Delete checkpoint?',
                                                              ),
                                                              content: const Text(
                                                                'This will delete the checkpoint for this checklist.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Get.back(
                                                                        result:
                                                                            false,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Get.back(
                                                                        result:
                                                                            true,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Delete',
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          if (confirm == true) {
                                                            try {
                                                              final svc =
                                                                  Get.find<
                                                                    PhaseChecklistService
                                                                  >();
                                                              await svc
                                                                  .deleteCheckpoint(
                                                                    sub['id']!,
                                                                  );
                                                              if (onRefresh !=
                                                                  null) {
                                                                await onRefresh!();
                                                              }
                                                            } catch (e) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Delete failed: $e',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          SubQuestionCard(
                                            key: ValueKey("${role}_$key"),
                                            subQuestion: text,
                                            editable: canEdit,
                                            role: role,
                                            initialData:
                                                answers[key] ??
                                                checklistCtrl.getAnswers(
                                                  projectId,
                                                  phase,
                                                  role,
                                                  key,
                                                ),
                                            onAnswer: (ans) => canEdit
                                                ? onAnswer(key, ans)
                                                : null,
                                            highlight: highlightSubs.contains(
                                              key,
                                            ),
                                            categoryInfo: getCategoryInfo?.call(
                                              sub['categoryId'],
                                            ),
                                            checkpointId: key,
                                            selectedCategoryId:
                                                selectedDefectCategory[key],
                                            selectedSeverity:
                                                selectedDefectSeverity[key],
                                            availableCategories:
                                                availableCategories,
                                            onCategoryAssigned: canEdit
                                                ? onCategoryAssigned
                                                : null,
                                            projectId: projectId,
                                            stageId: stageId,
                                            questionId: key,
                                            iterations:
                                                iterations, // Pass shared iterations down
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: widgets,
                                  );
                                }).toList();
                              }(),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// OPTIMIZATION: Pre-calculate differs efficiently with minimal getAnswers calls
  bool _calculateDiffers(
    List<Map<String, String>> subQuestions,
    Map<String, Map<String, dynamic>> answers,
    Map<String, Map<String, dynamic>> otherAnswers,
    ChecklistController checklistCtrl,
    String projectId,
    int phase,
    String role,
  ) {
    // Quickly fetch both role sheets once instead of per sub-question
    // Use cached references from the controller instead of creating new Map.from() copies
    final thisRoleSheet = checklistCtrl.getRoleSheetReference(
      projectId,
      phase,
      role,
    );
    final otherRole = role == 'executor' ? 'reviewer' : 'executor';
    final otherRoleSheet = checklistCtrl.getRoleSheetReference(
      projectId,
      phase,
      otherRole,
    );

    // Now check if any sub-question differs (no multiple getAnswers calls)
    for (final sub in subQuestions) {
      final key = (sub['id']?.isNotEmpty == true ? sub['id'] : sub['text'])!;

      // Get answers from merged sources (local map priority over cache)
      final aMap = answers[key] ?? thisRoleSheet[key];
      final bMap = otherAnswers[key] ?? otherRoleSheet[key];

      final a = aMap?['answer'];
      final b = bMap?['answer'];

      // Only show as different if BOTH have provided answers AND they differ
      if (a == null || b == null) continue;

      if (a == b) continue;

      final aStr = (a is String
          ? a.trim().toLowerCase()
          : a.toString().toLowerCase());
      final bStr = (b is String
          ? b.trim().toLowerCase()
          : b.toString().toLowerCase());

      if (aStr != bStr) return true; // Found a difference
    }
    return false; // No differences found
  }
}

class _DefectChip extends StatelessWidget {
  final int defectCount;
  final int checkpointCount;
  const _DefectChip({required this.defectCount, required this.checkpointCount});

  @override
  Widget build(BuildContext context) {
    final has = defectCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: has ? Colors.redAccent : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Mismatches: $defectCount',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ConflictCountBar extends StatelessWidget {
  final int conflictCount;
  const ConflictCountBar({required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    final hasConflicts = conflictCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasConflicts ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasConflicts ? Colors.orange : Colors.green,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasConflicts ? Icons.sync_problem : Icons.check_circle_outline,
            size: 22,
            color: hasConflicts ? Colors.orange.shade700 : Colors.green,
          ),
          const SizedBox(width: 10),
          const Text(
            'Conflict Count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasConflicts ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$conflictCount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConflictCounterBar extends StatelessWidget {
  final int conflictCount;
  const ConflictCounterBar({required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows, size: 22, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          const Text(
            'Conflict Counter',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$conflictCount',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewerSubmissionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> availableCategories;

  const ReviewerSubmissionSummaryCard({
    required this.summary,
    required this.availableCategories,
  });

  String _getCategoryName(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return 'None';
    try {
      final cat = availableCategories.firstWhere(
        (c) => (c['_id'] ?? '').toString() == categoryId,
        orElse: () => {},
      );
      return (cat['name'] ?? 'Unknown').toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remark = summary['remark']?.toString() ?? '';
    final category = summary['category']?.toString();
    final severity = summary['severity']?.toString();
    final categoryName = _getCategoryName(category);

    return Card(
      elevation: 3,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.orange.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reviewer Submission Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (remark.isNotEmpty) ...[
              const Text(
                'Remark:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(remark, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Defect Category:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Severity:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: severity == 'Critical'
                              ? Colors.red.shade100
                              : Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          severity ?? 'None',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: severity == 'Critical'
                                ? Colors.red.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ApprovalBanner extends StatelessWidget {
  final Map<String, dynamic>? approvalStatus;
  final Map<String, dynamic>? compareStatus;
  const ApprovalBanner({super.key, this.approvalStatus, this.compareStatus});

  @override
  Widget build(BuildContext context) {
    final status = approvalStatus?['status']?.toString() ?? 'none';
    String text = 'Approval: $status';
    Color bg = Colors.grey.shade200;

    if (status == 'pending') bg = Colors.amber.shade100;
    if (status == 'approved') bg = Colors.green.shade100;
    if (status == 'reverted') bg = Colors.red.shade100;
    if (status == 'reverted_to_executor') {
      bg = Colors.orange.shade100;
      text = 'Reverted to Executor - Waiting for executor to resubmit';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final String role;
  final String projectId;
  final int phase;
  final Future<void> Function() onSubmit;
  final Future<void> Function()? onRevert; // New: revert callback for reviewer
  final bool isCurrentUserReviewer; // Check if logged-in user is a reviewer
  final Map<String, dynamic>? submissionInfo;
  final Map<String, dynamic>?
  executorSubmissionInfo; // New: to check if executor submitted
  final bool canEdit;

  const _SubmitBar({
    required this.role,
    required this.projectId,
    required this.phase,
    required this.onSubmit,
    this.onRevert,
    this.isCurrentUserReviewer = false,
    required this.submissionInfo,
    this.executorSubmissionInfo,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context) {
    final submitted = submissionInfo?['is_submitted'] == true;
    final submittedAt = submissionInfo?['submitted_at'];

    // Check if executor has submitted (for reviewer to enable revert)
    final executorSubmitted = executorSubmissionInfo?['is_submitted'] == true;
    // Reviewer can revert to executor when executor submitted but reviewer hasn't
    final showRevertButton =
        role == 'reviewer' &&
        isCurrentUserReviewer &&
        !submitted &&
        executorSubmitted &&
        onRevert != null;

    // Reviewer can only submit/revert when executor has submitted
    final canReviewerSubmit = role == 'reviewer'
        ? (canEdit && executorSubmitted)
        : canEdit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          if (submitted)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                const Text('Submitted', style: TextStyle(color: Colors.green)),
              ],
            )
          else
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: canReviewerSubmit ? onSubmit : null,
                  icon: const Icon(Icons.send),
                  label: Text(
                    'Submit ${role[0].toUpperCase()}${role.substring(1)} Checklist',
                  ),
                ),
                if (showRevertButton) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onRevert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.undo),
                    label: const Text('Revert to Executor'),
                  ),
                ],
              ],
            ),
          const Spacer(),
          Text(role.toUpperCase(), style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class SubQuestionCard extends StatefulWidget {
  final String subQuestion;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onAnswer;
  final bool editable;
  final bool highlight;
  final Map<String, dynamic>? categoryInfo;
  final String? checkpointId; // Added: checkpoint ID for category assignment
  final String?
  selectedCategoryId; // New: controlled selected category from parent
  final String?
  selectedSeverity; // New: controlled selected severity from parent
  final List<Map<String, dynamic>>
  availableCategories; // Added: list of categories from template
  final Function(String checkpointId, String? categoryId, {String? severity})?
  onCategoryAssigned; // Added: callback for category assignment
  final String role; // Added: to restrict category UI to reviewer only
  final String? projectId; // Added: for fetching iterations
  final String? stageId; // Added: for fetching iterations
  final String? questionId; // Added: the MongoDB _id of this question

  final List<dynamic> iterations; // Added: shared iteration history

  const SubQuestionCard({
    super.key,
    required this.subQuestion,
    this.initialData,
    required this.onAnswer,
    this.editable = true,
    this.highlight = false,
    this.categoryInfo,
    this.checkpointId,
    this.selectedCategoryId,
    this.selectedSeverity,
    this.availableCategories = const [],
    this.onCategoryAssigned,
    this.role = 'reviewer', // Default to reviewer for backward compatibility
    this.projectId,
    this.stageId,
    this.questionId,
    this.iterations = const [],
  });

  @override
  State<SubQuestionCard> createState() => _SubQuestionCardState();
}

class _SubQuestionCardState extends State<SubQuestionCard> {
  static const Set<String> _allowedSeverityValues = {
    'Critical',
    'Non-Critical',
  };

  String? selectedOption;
  String? selectedCategory; // Added: for category assignment
  String? selectedSeverity; // Added: for severity assignment
  final TextEditingController remarkController = TextEditingController();
  List<Map<String, dynamic>> _images = [];
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestedCategories =
      []; // Added: for showing suggestion chips

  // Iteration history
  List<Map<String, dynamic>> _iterations = [];
  int _currentIteration = 1;
  int _selectedIterationNumber =
      0; // 0 means current, 1+ means viewing past iteration
  bool _loadingIterations = false;

  int _parseIterationNumber(dynamic rawValue) {
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.toInt();
    if (rawValue == null) return 0;
    return int.tryParse(rawValue.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _deduplicateIterations(
    List<dynamic> rawIterations,
  ) {
    final byNumber = <int, Map<String, dynamic>>{};
    for (final item in rawIterations) {
      if (item is! Map<String, dynamic>) continue;
      final number = _parseIterationNumber(item['iterationNumber']);
      if (number <= 0) continue;
      byNumber[number] = item;
    }

    final sorted = byNumber.values.toList()
      ..sort(
        (a, b) => ((b['iterationNumber'] as int?) ?? 0).compareTo(
          (a['iterationNumber'] as int?) ?? 0,
        ),
      );
    return sorted;
  }

  List<Map<String, dynamic>> _deduplicateCategories(
    List<Map<String, dynamic>> categories,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final cat in categories) {
      final id = (cat['_id'] ?? cat['id'] ?? '').toString();
      if (id.isEmpty) continue;
      byId[id] = cat;
    }
    return byId.values.toList();
  }

  String? _normalizeCategoryValue(
    String? value,
    List<Map<String, dynamic>> categories,
  ) {
    if (value == null || value.isEmpty) return null;
    final validIds = categories
        .map((c) => (c['_id'] ?? c['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    return validIds.contains(value) ? value : null;
  }

  String? _normalizeSeverityValue(String? value) {
    if (value == null || value.isEmpty) return null;
    return _allowedSeverityValues.contains(value) ? value : null;
  }

  Map<String, String> get _authHeaders {
    if (Get.isRegistered<AuthController>()) {
      final token = Get.find<AuthController>().currentUser.value?.token;
      if (token != null && token.isNotEmpty) {
        return {'Authorization': 'Bearer $token'};
      }
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Initialize iterations from prop instead of fetching
    _iterations = _deduplicateIterations(widget.iterations);

    // Attempt to determine current iteration number if not provided in data
    _currentIteration = _iterations.isNotEmpty
        ? _iterations
              .map((it) => _parseIterationNumber(it['iterationNumber']))
              .fold(0, (max, v) => v > max ? v : max)
        : 1;

    if (kDebugMode && widget.role == 'reviewer') {}

    // Images are already loaded from initialData['images'] which correctly
    // separates executorImages and reviewerImages from ProjectChecklist
    // No need to fetch from GridFS separately
    // _fetchExistingImages(); // REMOVED: causes images to show on wrong side
  }

  @override
  void didUpdateWidget(SubQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (kDebugMode && widget.role == 'reviewer') {
      if (widget.selectedCategoryId != oldWidget.selectedCategoryId ||
          widget.selectedSeverity != oldWidget.selectedSeverity) {}
    }

    // Keep historical selection stable while viewing past iterations.
    // Parent rebuilds should only sync current-iteration values.
    if (_selectedIterationNumber == 0) {
      if (widget.selectedCategoryId != oldWidget.selectedCategoryId) {
        final next = widget.selectedCategoryId;
        setState(
          () => selectedCategory = (next == null || next.isEmpty) ? null : next,
        );
      }
      if (widget.selectedSeverity != oldWidget.selectedSeverity) {
        setState(
          () => selectedSeverity = _normalizeSeverityValue(
            widget.selectedSeverity,
          ),
        );
      }
    }

    if (!listEquals(widget.iterations, oldWidget.iterations)) {
      final nextIterations = _deduplicateIterations(widget.iterations);
      setState(() {
        _iterations = nextIterations;
        _currentIteration = _iterations.isNotEmpty
            ? _iterations
                  .map((it) => _parseIterationNumber(it['iterationNumber']))
                  .fold(0, (max, v) => v > max ? v : max)
            : 1;
        if (_selectedIterationNumber > 0 &&
            !_iterations.any(
              (it) =>
                  _parseIterationNumber(it['iterationNumber']) ==
                  _selectedIterationNumber,
            )) {
          _selectedIterationNumber = 0;
        }
      });
    }
    // Re-initialize if initialData changed
    if (_selectedIterationNumber == 0 &&
        widget.initialData != oldWidget.initialData) {
      _initializeData();
    }
  }

  Map<String, dynamic>? _findQuestionInIterationByText(
    Map<String, dynamic> iteration,
    String questionText,
  ) {
    final target = questionText.trim().toLowerCase();
    if (target.isEmpty) return null;

    final groups = iteration['groups'] as List<dynamic>? ?? [];
    for (final group in groups) {
      if (group is! Map<String, dynamic>) continue;

      final questions = group['questions'] as List<dynamic>? ?? [];
      for (final q in questions) {
        if (q is! Map<String, dynamic>) continue;
        final text = (q['text'] ?? '').toString().trim().toLowerCase();
        if (text == target) return q;
      }

      final sections = group['sections'] as List<dynamic>? ?? [];
      for (final section in sections) {
        if (section is! Map<String, dynamic>) continue;
        final sectionQuestions = section['questions'] as List<dynamic>? ?? [];
        for (final q in sectionQuestions) {
          if (q is! Map<String, dynamic>) continue;
          final text = (q['text'] ?? '').toString().trim().toLowerCase();
          if (text == target) return q;
        }
      }
    }

    return null;
  }

  void _initializeData() {
    if (widget.initialData != null) {
      selectedOption = widget.initialData!['answer'];
      final newRemark = widget.initialData!['remark'] ?? '';
      if (remarkController.text != newRemark) remarkController.text = newRemark;
      final imgs = widget.initialData!['images'];
      if (imgs is List) _images = List<Map<String, dynamic>>.from(imgs);

      // Extract categoryId and severity from initialData for reviewer role
      // Prefer initialData over widget props
      if (widget.role == 'reviewer') {
        final initialCat = (widget.initialData!['categoryId'] ?? '').toString();
        final propCat = (widget.selectedCategoryId ?? '').toString();
        final resolvedCat = initialCat.isNotEmpty
            ? initialCat
            : (propCat.isNotEmpty ? propCat : '');
        selectedCategory = resolvedCat.isEmpty ? null : resolvedCat;

        final initialSev = (widget.initialData!['severity'] ?? '').toString();
        final propSev = (widget.selectedSeverity ?? '').toString();
        final resolvedSev = initialSev.isNotEmpty
            ? initialSev
            : (propSev.isNotEmpty ? propSev : '');
        selectedSeverity = _normalizeSeverityValue(
          resolvedSev.isEmpty ? null : resolvedSev,
        );
      }
    } else if (widget.role == 'reviewer') {
      final propCat = widget.selectedCategoryId;
      selectedCategory = (propCat == null || propCat.isEmpty) ? null : propCat;
      selectedSeverity = _normalizeSeverityValue(widget.selectedSeverity);
    }
  }

  // Redundant network fetch removed in favor of shared iterations prop
  Future<void> _loadIterations() async {
    return;
  }

  void _viewIteration(int iterationNumber) {
    if (iterationNumber == 0) {
      // View current iteration (reset to current data)
      setState(() {
        _selectedIterationNumber = 0;
        _initializeData(); // Reset to current data
      });
      return;
    }

    // Find the iteration
    final iteration = _iterations.firstWhere(
      (it) => _parseIterationNumber(it['iterationNumber']) == iterationNumber,
      orElse: () => {},
    );

    if (iteration.isEmpty) return;

    // Find this question in the iteration
    final iterationService = IterationService();
    Map<String, dynamic>? questionData;
    final currentQuestionId = widget.questionId;

    if (currentQuestionId != null && currentQuestionId.isNotEmpty) {
      questionData = iterationService.findQuestionInIteration(
        iteration,
        currentQuestionId,
      );
    }

    questionData ??= _findQuestionInIterationByText(
      iteration,
      widget.subQuestion,
    );

    if (questionData == null) {
      if (kDebugMode) {}
      return;
    }

    // Extract answers based on role
    final answers = iterationService.extractAnswersFromQuestion(questionData);

    if (kDebugMode) {
      if (widget.role == 'executor') {
      } else {}
    }

    setState(() {
      _selectedIterationNumber = iterationNumber;

      // Update displayed data based on role
      if (widget.role == 'executor') {
        selectedOption = answers['executorAnswer'];
        remarkController.text = answers['executorRemark'] ?? '';
        _images = List<Map<String, dynamic>>.from(
          answers['executorImages'] ?? [],
        );
      } else if (widget.role == 'reviewer') {
        selectedOption = answers['reviewerAnswer'];
        remarkController.text = answers['reviewerRemark'] ?? '';
        _images = List<Map<String, dynamic>>.from(
          answers['reviewerImages'] ?? [],
        );
        // Convert empty strings to null for dropdown compatibility
        final catId = answers['categoryId']?.toString();
        selectedCategory = (catId == null || catId.isEmpty) ? null : catId;
        final sev = answers['severity']?.toString();
        selectedSeverity = _normalizeSeverityValue(
          (sev == null || sev.isEmpty) ? null : sev,
        );
      }
    });

    if (kDebugMode) {}
  }

  @override
  void dispose() {
    remarkController.dispose();
    super.dispose();
  }

  Future<void> _updateAnswer() {
    final answerData = <String, dynamic>{
      "answer": selectedOption,
      "remark": remarkController.text,
      "images": _images,
    };

    // Include categoryId and severity for reviewer role
    if (widget.role == 'reviewer') {
      // Always include these fields, even if null, so they can be cleared
      answerData['categoryId'] = selectedCategory ?? '';
      answerData['severity'] = selectedSeverity ?? '';

      if (kDebugMode) {}
    }

    return widget.onAnswer(answerData);
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        // Upload each selected image to backend GridFS, associated by questionId and role
        final uploaded = <Map<String, dynamic>>[];
        int failedCount = 0;
        String? firstFailureReason;
        for (final f in result.files) {
          if (f.bytes == null) continue;
          try {
            final effectiveQuestionId =
                (widget.checkpointId ?? widget.subQuestion).toString();
            final req = http.MultipartRequest(
              'POST',
              Uri.parse(
                '$_imageBaseUrl/images/$effectiveQuestionId?role=${widget.role}',
              ),
            );
            req.headers.addAll(_authHeaders);
            req.fields['question_id'] = effectiveQuestionId;
            if (widget.projectId != null && widget.projectId!.isNotEmpty) {
              req.fields['project_id'] = widget.projectId!;
            }
            // stageId is sent as checklist_id; backend resolves to projectChecklist id.
            if (widget.stageId != null && widget.stageId!.isNotEmpty) {
              req.fields['checklist_id'] = widget.stageId!;
            }
            if (selectedCategory != null && selectedCategory!.isNotEmpty) {
              req.fields['defect_id'] = selectedCategory!;
            }
            req.fields['role'] = widget.role;
            req.files.add(
              http.MultipartFile.fromBytes('image', f.bytes!, filename: f.name),
            );
            final streamed = await req.send();
            final resp = await http.Response.fromStream(streamed);
            if (resp.statusCode == 201) {
              final data = jsonDecode(resp.body) as Map<String, dynamic>;
              uploaded.add({
                'fileId': data['fileId'],
                'filename': data['filename'],
              });
            } else {
              if (firstFailureReason == null) {
                String reason = 'Upload failed (HTTP ${resp.statusCode})';
                try {
                  final body = jsonDecode(resp.body);
                  if (body is Map<String, dynamic>) {
                    final apiMsg = (body['error'] ?? body['message'] ?? '')
                        .toString();
                    if (apiMsg.isNotEmpty) reason = apiMsg;
                  }
                } catch (_) {}
                firstFailureReason = reason;
              }
              failedCount++;
            }
          } catch (e) {
            firstFailureReason ??= e.toString();
            failedCount++;
          }
        }
        if (uploaded.isNotEmpty) {
          setState(() => _images = [..._images, ...uploaded]);
          await _updateAnswer();
        }
        if (failedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                firstFailureReason == null
                    ? '$failedCount image(s) failed to upload'
                    : '$failedCount image(s) failed to upload: $firstFailureReason',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick images'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final currentCat = _currentSelectedCategory();
    final dedupedCategories = _deduplicateCategories(
      widget.availableCategories,
    );
    final safeCategoryValue = _normalizeCategoryValue(
      selectedCategory,
      dedupedCategories,
    );
    final safeSeverityValue = _normalizeSeverityValue(selectedSeverity);

    final base = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.subQuestion,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Iteration history dropdown - show only if we have iterations
            if (_iterations.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedIterationNumber == 0
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedIterationNumber == 0
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                    width: 1,
                  ),
                ),
                child: DropdownButton<int>(
                  value: _selectedIterationNumber,
                  underline: const SizedBox(),
                  isDense: true,
                  icon: Icon(
                    Icons.history,
                    size: 18,
                    color: _selectedIterationNumber == 0
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedIterationNumber == 0
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            size: 8,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text('Current (v$_currentIteration)'),
                        ],
                      ),
                    ),
                    ..._iterations.map((iteration) {
                      final iterNum = iteration['iterationNumber'] as int;
                      return DropdownMenuItem(
                        value: iterNum,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text('Iteration $iterNum'),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _viewIteration(value);
                    }
                  },
                ),
              ),
            ],
            if (widget.categoryInfo != null) ...[],
          ],
        ),
        // Show viewing notice when viewing past iteration
        if (_selectedIterationNumber > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewing Iteration $_selectedIterationNumber (Read-only)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text("Yes"),
                value: "Yes",
                groupValue: selectedOption,
                contentPadding: EdgeInsets.zero,
                onChanged: (widget.editable && _selectedIterationNumber == 0)
                    ? (val) async {
                        setState(() => selectedOption = val);
                        await _updateAnswer();
                      }
                    : null,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text("No"),
                value: "No",
                groupValue: selectedOption,
                contentPadding: EdgeInsets.zero,
                onChanged: (widget.editable && _selectedIterationNumber == 0)
                    ? (val) async {
                        setState(() => selectedOption = val);
                        await _updateAnswer();
                      }
                    : null,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text("Not Applicable"),
                value: "NA",
                groupValue: selectedOption,
                contentPadding: EdgeInsets.zero,
                onChanged: (widget.editable && _selectedIterationNumber == 0)
                    ? (val) async {
                        setState(() => selectedOption = val);
                        await _updateAnswer();
                      }
                    : null,
              ),
            ),
          ],
        ),
        // Allow clearing an existing answer when editable
        if (widget.editable &&
            selectedOption != null &&
            _selectedIterationNumber == 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                setState(() {
                  selectedOption = null;
                });
                await _updateAnswer();
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear answer'),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: remarkController,
                onChanged: (widget.editable && _selectedIterationNumber == 0)
                    ? _onRemarkChanged
                    : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  hintText: "Remark",
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
                enabled: (widget.editable && _selectedIterationNumber == 0),
                maxLines: null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: (widget.editable && _selectedIterationNumber == 0)
                  ? _pickImages
                  : null,
            ),
          ],
        ),
        // Show suggested categories for reviewer role as blue pills below remark
        if (widget.role == 'reviewer' && _suggestedCategories.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestedCategories.map((cat) {
              final id = (cat['_id'] ?? '').toString();
              final name = (cat['name'] ?? '').toString();
              final isSelected = selectedCategory == id;
              return GestureDetector(
                onTap: widget.editable
                    ? () {
                        setState(() {
                          selectedCategory = id;
                        });
                        if (widget.checkpointId != null &&
                            widget.onCategoryAssigned != null) {
                          widget.onCategoryAssigned!(
                            widget.checkpointId!,
                            id,
                            severity: selectedSeverity,
                          );
                        }
                        _updateAnswer();
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.shade700
                        : Colors.blue.shade500,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: Colors.blue.shade900, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(33, 150, 243, 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        // Add defect category and severity for reviewer role
        if (widget.role == 'reviewer') ...[
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: safeCategoryValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: 'Defect Category',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...() {
                        final groups = <String, List<Map<String, dynamic>>>{};
                        for (final cat in dedupedCategories) {
                          final g = (cat['group'] ?? 'General').toString();
                          groups.putIfAbsent(g, () => []).add(cat);
                        }

                        final items = <DropdownMenuItem<String>>[];
                        final sortedGroups = groups.keys.toList()..sort();

                        for (final g in sortedGroups) {
                          // HEADER (Disabled)
                          items.add(
                            DropdownMenuItem<String>(
                              enabled: false,
                              value: 'HEADER_$g', // Unique dummy value
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.black12),
                                  ),
                                ),
                                child: Text(
                                  g.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          );

                          // CATEGORIES in this group
                          final sortedCats = groups[g]!
                            ..sort(
                              (a, b) => (a['name'] ?? '').toString().compareTo(
                                (b['name'] ?? '').toString(),
                              ),
                            );

                          for (final cat in sortedCats) {
                            final id = (cat['_id'] ?? cat['id'] ?? '')
                                .toString();
                            final name = (cat['name'] ?? 'Unknown').toString();
                            if (id.isEmpty) continue;

                            items.add(
                              DropdownMenuItem<String>(
                                value: id,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                        return items;
                      }(),
                    ],
                    onChanged:
                        (widget.editable && _selectedIterationNumber == 0)
                        ? (val) {
                            setState(() => selectedCategory = val);
                            // Update parent state only, no backend call
                            if (widget.checkpointId != null &&
                                widget.onCategoryAssigned != null) {
                              widget.onCategoryAssigned!(
                                widget.checkpointId!,
                                val,
                                severity: selectedSeverity,
                              );
                            }
                            // Save will happen through updateCheckpointResponse
                            _updateAnswer();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: safeSeverityValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: 'Severity',
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(
                        value: 'Critical',
                        child: Text('Critical'),
                      ),
                      DropdownMenuItem(
                        value: 'Non-Critical',
                        child: Text('Non-Critical'),
                      ),
                    ],
                    onChanged:
                        (widget.editable && _selectedIterationNumber == 0)
                        ? (val) {
                            setState(() => selectedSeverity = val);
                            // Update parent state only, no backend call
                            if (widget.checkpointId != null &&
                                widget.onCategoryAssigned != null) {
                              widget.onCategoryAssigned!(
                                widget.checkpointId!,
                                selectedCategory,
                                severity: val,
                              );
                            }
                            // Save will happen through updateCheckpointResponse
                            _updateAnswer();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_images.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, i) {
                final img = _images[i];

                if (kDebugMode) {}

                final bytes = img['bytes'] is Uint8List
                    ? img['bytes'] as Uint8List
                    : null;
                final name = img['name'] is String
                    ? img['name'] as String
                    : (img['filename'] is String
                          ? img['filename'] as String
                          : null);

                // If we have local bytes (just picked), show memory; else try server fileId
                // Handle both string and ObjectId formats
                final fileId = (img['fileId'] ?? '').toString();

                if (kDebugMode) {}

                if (bytes == null && fileId.isEmpty)
                  return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _openImageViewer(
                          fileId: fileId,
                          bytes: bytes,
                          name: name,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: bytes != null
                              ? Image.memory(
                                  bytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  '$_imageBaseUrl/images/file/$fileId',
                                  headers: _authHeaders,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                  errorBuilder: (_, error, ___) {
                                    if (kDebugMode) {}
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey.shade300,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            color: Colors.grey.shade600,
                                            size: 32,
                                          ),
                                          if (_selectedIterationNumber > 0) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Missing',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      if (widget.editable && _selectedIterationNumber == 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () async {
                              final fileId = (img['fileId'] ?? '').toString();
                              // If this image exists on server, request deletion
                              if (fileId.isNotEmpty) {
                                try {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete image?'),
                                      content: const Text(
                                        'Are you sure you want to delete this image?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await http.delete(
                                      Uri.parse(
                                        '$_imageBaseUrl/images/file/$fileId',
                                      ),
                                      headers: _authHeaders,
                                    );
                                    // Remove from local list only after deletion confirmed
                                    setState(() => _images.removeAt(i));
                                    await _updateAnswer();
                                  }
                                } catch (_) {}
                              } else {
                                // For local images without fileId, just remove
                                setState(() => _images.removeAt(i));
                                await _updateAnswer();
                              }
                            },
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      if (name != null)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Container(
                            color: Colors.black45,
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
    return widget.highlight
        ? Container(
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Padding(padding: const EdgeInsets.all(6.0), child: base),
          )
        : base;
  }

  void _openImageViewer({String? fileId, Uint8List? bytes, String? name}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx).size;
        final width = media.width;
        final height = media.height;
        Widget image;
        if (bytes != null) {
          image = Image.memory(bytes, fit: BoxFit.contain);
        } else if (fileId != null && fileId.isNotEmpty) {
          image = Image.network(
            '$_imageBaseUrl/images/file/$fileId',
            headers: _authHeaders,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, error, ___) {
              if (kDebugMode) {}
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'File: ${name ?? fileId}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          image = const SizedBox.shrink();
        }
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(child: image),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                if (name != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Debounced remark handler
  void _onRemarkChanged(String newRemark) {
    _debounceTimer?.cancel();
    // Save answer IMMEDIATELY on every keystroke (don't debounce the save)
    _updateAnswer();
    // But debounce the suggestion computation for reviewer role
    if (widget.role == 'reviewer') {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _computeLocalSuggestions(newRemark);
      });
    }
  }

  void _computeLocalSuggestions(String remark) {
    final text = remark.trim();
    if (text.length < 2 || widget.availableCategories.isEmpty) {
      setState(() {
        _suggestedCategories = [];
      });
      return;
    }
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      setState(() {
        _suggestedCategories = [];
      });
      return;
    }
    final suggestions = <Map<String, dynamic>>[];
    for (final cat in widget.availableCategories) {
      final name = (cat['name'] ?? '').toString();
      final id = (cat['_id'] ?? '').toString();
      // Gather keywords with graceful fallbacks: keywords[] â†’ aliases[] â†’ name tokens
      final kwFromArray = (cat['keywords'] as List<dynamic>? ?? [])
          .map((k) => k.toString().toLowerCase())
          .where((k) => k.trim().isNotEmpty)
          .toList();
      final aliasArray = (cat['aliases'] as List<dynamic>? ?? [])
          .map((k) => k.toString().toLowerCase())
          .where((k) => k.trim().isNotEmpty)
          .toList();
      final nameTokens = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      final kws = [
        ...kwFromArray,
        ...aliasArray,
        ...nameTokens,
      ].toSet().toList();
      if (id.isEmpty || kws.isEmpty) continue;
      double matchCount = 0;
      for (final token in normalized) {
        for (final kw in kws) {
          if (token == kw) {
            matchCount += 1;
          } else if (kw.contains(token) || token.contains(kw)) {
            matchCount += 0.5;
          }
        }
      }
      if (matchCount > 0) {
        suggestions.add({'_id': id, 'name': name, 'matchScore': matchCount});
      }
    }
    // Sort by match score descending, then by name
    suggestions.sort((a, b) {
      final scoreA = a['matchScore'] as double;
      final scoreB = b['matchScore'] as double;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Higher score first
      }
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    // Update the suggestions list to show as blue chips
    // Limit to top 5 suggestions
    setState(() {
      _suggestedCategories = suggestions.take(5).toList();
    });
  }
}
