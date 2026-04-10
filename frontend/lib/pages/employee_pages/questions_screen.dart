import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:quality_review/controllers/auth_controller.dart';
import 'package:quality_review/pages/employee_pages/checklist.dart';
import 'package:quality_review/pages/employee_pages/checklist_controller.dart';
import 'package:quality_review/services/approval_service.dart';
import 'package:quality_review/services/phase_checklist_service.dart';
import 'package:quality_review/services/template_service.dart';
import 'package:quality_review/services/stage_service.dart';
import 'package:quality_review/services/project_checklist_service.dart';

class QuestionsScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final List<String> leaders;
  final List<String> reviewers;
  final List<String> executors;
  final int? initialPhase;
  final String? initialSubQuestion;
  final String templateName;

  const QuestionsScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.leaders,
    required this.reviewers,
    required this.executors,
    this.initialPhase,
    this.initialSubQuestion,
    required this.templateName,
  });

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final Map<String, Map<String, dynamic>> executorAnswers = {};
  final Map<String, Map<String, dynamic>> reviewerAnswers = {};
  final Set<int> executorExpanded = {};
  final Set<int> reviewerExpanded = {};
  String? _errorMessage;
  bool _editMode = false;
  late final ChecklistController checklistCtrl;
  late final ApprovalService _approvalService;
  String? _currentStageId;
  bool _isLoadingData = true;
  bool _isLoadingQuestions = false;
  // Phase numbering: 1, 2, 3... directly maps to stage1, stage2, stage3...
  int _selectedPhase = 1; // Currently selected phase (1 = first phase)
  int _activePhase = 1; // Active phase index (enabled for editing)
  int _maxActualPhase = 7; // Max phase number discovered from stages
  List<int> _availablePhaseNumbers = [1]; // Real phases from stage keys
  bool _isProjectCompleted = false; // Track if all phases are completed
  Map<String, dynamic> _stageMap = {}; // Map stageKey to stage data
  Map<String, dynamic>? _approvalStatus;
  Map<String, dynamic>? _compareStatus;
  final ScrollController _executorScroll = ScrollController();
  final ScrollController _reviewerScroll = ScrollController();
  final Set<String> _highlightSubs = {};
  List<Question> checklist = []; // Checklist questions for current phase
  Map<String, String> _checkpointIdMap =
      {}; // Cache: subQuestion text/id -> checkpoint ID (for fast lookup)

  // Defect tracking and category state
  Map<String, int> _defectsByChecklist = {};
  Map<String, int> _checkpointsByChecklist =
      {}; // Track checkpoints per checklist
  // Track cumulative defect count per phase (from backend)
  final Map<int, int> _cumulativeDefectCount = {};
  final Map<String, String?> _selectedDefectCategory = {};
  final Map<String, String?> _selectedDefectSeverity = {};
  Map<String, Map<String, dynamic>> _defectCategories = {};
  String _reviewerSummaryKey = '_meta_reviewer_summary';

  // Counters and metrics
  // Store conflict counter per phase (key: phase number, value: conflict count)
  final Map<int, int> _conflictCounters = {};
  int _maxDefectsSeenInSession = 0;
  int _totalCheckpointsInSession = 0;
  // Track loopback count per phase (key: phase number, value: loopback count)
  final Map<int, int> _loopbackCounters = {};

  // Defect rate tracking
  double _overallDefectRate = 0.0;
  List<Map<String, dynamic>> _iterationsWithRates = [];
  List<dynamic> _historicalIterationsFull = []; // Stores full group snapshots for iterations
  Map<String, dynamic>? _currentIterationStats;
  int? _selectedIterationNumber;
  List<DropdownMenuItem<int>> _cachedDropdownItems = [];

  // Persisted reviewer submission summary per phase
  final Map<int, Map<String, dynamic>> _reviewerSubmissionSummaries = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers/services
    checklistCtrl = Get.find<ChecklistController>();
    _approvalService = Get.find<ApprovalService>();

    // Clear cache to ensure fresh data when opening this screen
    // This prevents stale submission status from previous session
    checklistCtrl.clearProjectCache(widget.projectId);

    // Initial load
    _loadChecklistData();
  }

  List<Map<String, dynamic>> _getAvailableCategories() {
    return _defectCategories.values.toList();
  }

  Map<String, dynamic>? _getCategoryInfo(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return null;
    return _defectCategories[categoryId];
  }

  Future<void> _assignDefectCategory(
    String checkpointId,
    String? categoryId, {
    String? severity,
  }) async {
    // Only update local state - actual save happens through updateCheckpointResponse
    setState(() {
      _selectedDefectCategory[checkpointId] = categoryId;
      // Always update severity (including null = None), so clearing works correctly
      _selectedDefectSeverity[checkpointId] = severity;
    });
  }

  /// Handle reviewer reverting the phase back to executor
  /// This allows the executor to re-fill the checklist if the reviewer is not satisfied
  /// The cycle continues until the reviewer is satisfied and approves
  Future<void> _handleReviewerRevert() async {
    // Check if current user is a reviewer
    String? currentUserName;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      currentUserName = auth.currentUser.value?.name;
    }
    final canEditReviewer =
        currentUserName != null &&
        widget.reviewers
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    if (!canEditReviewer) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert to Executor'),
        content: const Text(
          'Are you sure you want to send this phase back to the executor? '
          'The executor will need to review and resubmit their work. '
          'This cycle can continue until you are satisfied with the results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _approvalService.revertToExecutor(widget.projectId, _selectedPhase);

      // Clear cache to ensure fresh data is loaded
      checklistCtrl.clearProjectCache(widget.projectId);

      // Reload checklist data to reflect the revert
      await _loadChecklistData();

      if (mounted) {
        // Force UI rebuild to show updated submission status
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phase reverted to executor successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revert: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadChecklistData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
      _isLoadingQuestions = true;
      _approvalStatus = null;
      _compareStatus = null;
      _errorMessage = null;
      // Clear previous category/severity data before loading fresh data
      _selectedDefectCategory.clear();
      _selectedDefectSeverity.clear();
    });

    int phase = _selectedPhase;

    try {
      // Step 0: Load defect categories from template
      try {
        final templateService = Get.find<TemplateService>();
        final template = await templateService.fetchTemplate(templateName: widget.templateName);
        final cats = template['defectCategories'] as List<dynamic>? ?? [];
        _defectCategories = {};
        for (final cat in cats) {
          if (cat is Map<String, dynamic>) {
            final id = ((cat['_id'] ?? cat['id'] ?? '') as Object).toString();
            if (id.isNotEmpty) {
              final normalised = Map<String, dynamic>.from(cat);
              normalised['_id'] = id;
              _defectCategories[id] = normalised;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print("Defect Category Load Error: $e");
      }

      // Step 1: Fetch stages
      final stageService = Get.find<StageService>();
      final stages = await stageService.listStages(widget.projectId, forceRefresh: true);

      int discoveredMaxActual = 1;
      final discoveredPhaseNumbers = <int>{};
      final stageMap = <String, dynamic>{};
      final conflictCountersMap = <int, int>{};

      for (final s in stages) {
        final name = (s['stage_name'] ?? '').toString();
        final stageKey = (s['stage_key'] ?? '').toString();
        stageMap[stageKey] = {'name': name, ...s};

        final match = RegExp(r'stage(\d+)', caseSensitive: false).firstMatch(stageKey);
        if (match != null) {
          final p = int.tryParse(match.group(1) ?? '') ?? 0;
          if (p > discoveredMaxActual) discoveredMaxActual = p;
          if (p > 0) discoveredPhaseNumbers.add(p);

          final conflictValue = s['conflict_count'];
          final conflictCount = conflictValue is int
              ? conflictValue
              : (conflictValue is double ? conflictValue.toInt() : 0);
          conflictCountersMap[p] = conflictCount;
        }
      }

      final availablePhases = discoveredPhaseNumbers.toList()..sort();

      if (mounted) {
        setState(() {
          _stageMap = stageMap;
          _maxActualPhase = discoveredMaxActual;
          _availablePhaseNumbers = availablePhases.isEmpty ? [1] : availablePhases;
          _conflictCounters.clear();
          _conflictCounters.addAll(conflictCountersMap);

          if (!_availablePhaseNumbers.contains(_selectedPhase)) {
            _selectedPhase = _availablePhaseNumbers.isEmpty ? 1 : _availablePhaseNumbers.first;
          }
        });
      }

      phase = _selectedPhase;

      if (stages.isEmpty) {
        throw Exception('No stages/checklists found. Ensure the template exists and the project is started.');
      }

      final expectedStageKey = 'stage$phase';
      final stage = stages.firstWhereOrNull((s) {
        final stageKey = (s['stage_key'] ?? '').toString().toLowerCase();
        return stageKey == expectedStageKey;
      });

      if (stage == null) {
        throw Exception('No stage found for Phase $phase (looking for $expectedStageKey).');
      }

      final stageId = (stage['_id'] ?? '').toString();
      _currentStageId = stageId;

      List<Question> loadedChecklist = [];
      try {
        final projectChecklistService = Get.find<ProjectChecklistService>();
        final projectChecklistData = await projectChecklistService.fetchChecklist(widget.projectId, stageId);

        _historicalIterationsFull = projectChecklistData['iterations'] as List<dynamic>? ?? [];
        final groups = projectChecklistData['groups'] as List<dynamic>? ?? [];
        
        if (groups.isNotEmpty) {
          loadedChecklist = Question.fromProjectChecklistGroups(groups);
          int totalDefects = 0;
          final defectCategories = <String, String?>{};
          final defectSeverities = <String, String?>{};

          for (final group in groups) {
            if (group is! Map<String, dynamic>) continue;
            totalDefects += group['defectCount'] as int? ?? 0;

            final directQuestions = group['questions'] as List<dynamic>? ?? [];
            for (final q in directQuestions) {
              if (q is! Map<String, dynamic>) continue;
              final questionId = (q['_id'] ?? '').toString();
              if (questionId.isEmpty) continue;
              final reviewerResp = q['reviewerResponse'] as Map<String, dynamic>? ?? {};
              final defectCatId = (reviewerResp['categoryId'] ?? '').toString();
              if (defectCatId.isNotEmpty) {
                defectCategories[questionId] = defectCatId;
                defectSeverities[questionId] = (reviewerResp['severity'] ?? '').toString();
              }
            }

            final sections = group['sections'] as List<dynamic>? ?? [];
            for (final section in sections) {
              if (section is! Map<String, dynamic>) continue;
              final sectionQuestions = section['questions'] as List<dynamic>? ?? [];
              for (final q in sectionQuestions) {
                if (q is! Map<String, dynamic>) continue;
                final questionId = (q['_id'] ?? '').toString();
                if (questionId.isEmpty) continue;
                final reviewerResp = q['reviewerResponse'] as Map<String, dynamic>? ?? {};
                final defectCatId = (reviewerResp['categoryId'] ?? '').toString();
                if (defectCatId.isNotEmpty) {
                  defectCategories[questionId] = defectCatId;
                  defectSeverities[questionId] = (reviewerResp['severity'] ?? '').toString();
                }
              }
            }
          }

          if (mounted) {
            setState(() {
              _cumulativeDefectCount[phase] = totalDefects;
              _selectedDefectCategory.addAll(defectCategories);
              _selectedDefectSeverity.addAll(defectSeverities);
            });
          }
        }
      } catch (e) {
        if (kDebugMode) print("ProjectChecklist Fetch Error: $e");
      }

      if (loadedChecklist.isEmpty) {
        try {
          final templateService = Get.find<TemplateService>();
          final template = await templateService.fetchTemplate(templateName: widget.templateName);
          final stageKey = 'stage$phase';
          final stageData = template[stageKey];
          if (stageData is List && stageData.isNotEmpty) {
            loadedChecklist = _questionsFromTemplateStage(stageData);
          }
        } catch (e) {}
      }

      if (mounted) {
        setState(() {
          checklist = loadedChecklist;
        });
        _buildCheckpointIdMap();
      }

      // Step 5: Load answers and rates in parallel
      await Future.wait([
        checklistCtrl.loadAnswers(widget.projectId, phase, 'executor'),
        checklistCtrl.loadAnswers(widget.projectId, phase, 'reviewer'),
        _loadDefectRates().catchError((e) => null),
        _computeActivePhase().catchError((e) => null),
      ]).timeout(const Duration(seconds: 30), onTimeout: () {
        if (kDebugMode) print("Step 5 loading timed out");
        return [];
      });

      if (mounted) {
        setState(() {
          executorAnswers.clear();
          executorAnswers.addAll(checklistCtrl.getRoleSheet(widget.projectId, phase, 'executor'));
          reviewerAnswers.clear();
          reviewerAnswers.addAll(checklistCtrl.getRoleSheet(widget.projectId, phase, 'reviewer'));
        });
      }

      _recomputeDefects();
    } catch (e) {
      if (kDebugMode) print("Error in _loadChecklistData: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _isLoadingQuestions = false;
        });
      }
    }

    // Step 6: Initial scroll/expand
    if (widget.initialSubQuestion != null && mounted) {
      final target = widget.initialSubQuestion!;
      final idx = checklist.indexWhere((q) => q.subQuestions.any((s) => s['text'] == target || s['id'] == target));
      if (idx != -1) {
        final matched = checklist[idx].subQuestions.firstWhere((s) => s['text'] == target || s['id'] == target);
        final key = (matched['id'] ?? matched['text'])!;
        setState(() {
          executorExpanded.add(idx);
          reviewerExpanded.add(idx);
          _highlightSubs.add(key);
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _highlightSubs.remove(key));
        });
      }
    }
  }

  /// Load defect rates per iteration and overall defect rate
  Future<void> _loadDefectRates() async {
    try {
      final checklistService = Get.find<ProjectChecklistService>();

      // Load both defect rate calls in parallel
      final results = await Future.wait([
        checklistService.getDefectRatesPerIteration(
          widget.projectId,
          _selectedPhase,
        ),
        checklistService.getOverallDefectRate(widget.projectId),
      ]);

      final iterationData = results[0];
      final overallData = results[1];

      if (!mounted) return;

      setState(() {
        // Parse iterations data
        final iterations = iterationData['iterations'] as List<dynamic>? ?? [];

        // Deduplicate iterations by iteration number
        final Map<int, Map<String, dynamic>> uniqueIterations = {};
        for (final iter in iterations) {
          if (iter is! Map<String, dynamic>) continue;
          final iterNum = iter['iterationNumber'] ?? 0;
          uniqueIterations[iterNum] = {
            'iterationNumber': iterNum,
            'defectRate': (iter['defectRate'] ?? 0.0).toDouble(),
            'totalDefects': iter['totalDefects'] ?? 0,
            'totalQuestions': iter['totalQuestions'] ?? 0,
            'revertedAt': iter['revertedAt'],
            'revertNotes': iter['revertNotes'],
          };
        }
        _iterationsWithRates = uniqueIterations.values.toList()
          ..sort(
            (a, b) => (b['iterationNumber'] as int).compareTo(
              a['iterationNumber'] as int,
            ),
          );

        // Auto-select current iteration if none selected
        if (_selectedIterationNumber == null && _currentIterationStats != null) {
          _selectedIterationNumber = _currentIterationStats!['iterationNumber'];
        }

        // Parse current iteration data
        final current = iterationData['current'];
        if (current != null && current is Map<String, dynamic>) {
          _currentIterationStats = {
            'iterationNumber': current['iterationNumber'] ?? 1,
            'defectRate': (current['defectRate'] ?? 0.0).toDouble(),
            'totalDefects': current['totalDefects'] ?? 0,
            'totalQuestions': current['totalQuestions'] ?? 0,
          };
        }

        // Parse overall defect rate
        _overallDefectRate = (overallData['overallDefectRate'] ?? 0.0)
            .toDouble();

        // Initialize selected iteration to current iteration if not set
        if (_selectedIterationNumber == null &&
            _currentIterationStats != null) {
          _selectedIterationNumber =
              _currentIterationStats!['iterationNumber'] as int;
        }

        // Rebuild dropdown items
        _rebuildDropdownItems();
      });
    } catch (e) {
      // Silently fail - don't disrupt the UI
    }
  }

  // Build dropdown items for iteration selector with proper deduplication
  void _rebuildDropdownItems() {
    // Collect all unique iteration numbers and their labels
    final Map<int, String> iterationMap = {};

    // Add current iteration first if it exists
    if (_currentIterationStats != null) {
      final currentNum = _currentIterationStats!['iterationNumber'] as int;
      iterationMap[currentNum] = 'Current ($currentNum)';
    }

    // Add previous iterations (will not override if already exists)
    for (final iter in _iterationsWithRates) {
      final iterNum = iter['iterationNumber'] as int;
      if (!iterationMap.containsKey(iterNum)) {
        iterationMap[iterNum] = 'Iteration $iterNum';
      }
    }

    // Build dropdown items from the map (guaranteed unique by Map keys)
    _cachedDropdownItems = iterationMap.entries.map((entry) {
      return DropdownMenuItem<int>(
        value: entry.key,
        child: Text(entry.value, style: const TextStyle(fontSize: 13)),
      );
    }).toList();

    // Debug logging

    // Validate _selectedIterationNumber is in the items
    if (_selectedIterationNumber != null && _cachedDropdownItems.isNotEmpty) {
      final hasSelectedValue = _cachedDropdownItems.any(
        (item) => item.value == _selectedIterationNumber,
      );
      if (!hasSelectedValue) {
        _selectedIterationNumber = _cachedDropdownItems.first.value;
      }
    }
  }

  // Convert admin template stage data to our Questions structure
  List<Question> _questionsFromTemplateStage(List<dynamic> stageData) {
    final questions = <Question>[];
    for (final group in stageData) {
      if (group is! Map<String, dynamic>) continue;
      final groupId = (group['_id'] ?? '').toString();
      final groupName = (group['text'] ?? group['groupName'] ?? '').toString();
      if (groupName.isEmpty) continue;

      final subs = <Map<String, String>>[];

      // Direct checkpoints/questions under group
      final checkpoints = (group['checkpoints'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final cp in checkpoints) {
        subs.add({
          'id': (cp['_id'] ?? '').toString(),
          'text': (cp['text'] ?? cp['question'] ?? '').toString(),
          'categoryId': (cp['categoryId'] ?? '').toString(),
        });
      }

      // Section-based checkpoints/questions
      final sections = (group['sections'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final section in sections) {
        final sectionName = (section['text'] ?? section['sectionName'] ?? '')
            .toString();
        final sectionCps = (section['checkpoints'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final sectionQs = (section['questions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        for (final cp in sectionCps) {
          subs.add({
            'id': (cp['_id'] ?? '').toString(),
            'text': (cp['text'] ?? cp['question'] ?? '').toString(),
            'categoryId': (cp['categoryId'] ?? '').toString(),
            'sectionName': sectionName,
          });
        }
        for (final q in sectionQs) {
          subs.add({
            'id': (q['_id'] ?? '').toString(),
            'text': (q['text'] ?? '').toString(),
            'categoryId': (q['categoryId'] ?? '').toString(),
            'sectionName': sectionName,
          });
        }
      }

      if (subs.isNotEmpty) {
        questions.add(
          Question(
            mainQuestion: groupName,
            subQuestions: subs
                .where((m) => (m['text'] ?? '').isNotEmpty)
                .toList(),
            checklistId: groupId,
          ),
        );
      }
    }
    return questions;
  }

  /// Builds a cache map of (subQuestion text/id) -> checkpoint ID for fast lookup
  /// This is called once after checklist is loaded to avoid O(n) searches on every keystroke
  void _buildCheckpointIdMap() {
    _checkpointIdMap.clear();
    for (final q in checklist) {
      for (final sub in q.subQuestions) {
        final subId = (sub['id'] ?? '').toString();
        final subText = (sub['text'] ?? '').toString();
        final checkpointId = (sub['id'] ?? '').toString();

        // Map both the text and id to the checkpoint ID for flexible lookup
        if (subText.isNotEmpty) {
          _checkpointIdMap[subText] = checkpointId;
        }
        if (subId.isNotEmpty) {
          _checkpointIdMap[subId] = checkpointId;
        }
      }
    }
  }

  /// Handle iteration change to swap displayed answers
  void _onIterationChanged(int iterationNumber) {
    if (iterationNumber == _selectedIterationNumber) return;

    setState(() {
      _selectedIterationNumber = iterationNumber;
      _isLoadingData = true; // Briefly show loading while we swap data
    });

    try {
      // Check if it's the current active iteration
      if (_currentIterationStats != null &&
          iterationNumber == _currentIterationStats!['iterationNumber']) {
        // Current iteration: Just reload the latest answers as normal
        _loadChecklistData();
        return;
      }

      // Historical iteration: Extract answers from the stored snapshots
      final historical = _historicalIterationsFull.firstWhereOrNull(
        (it) => it['iterationNumber'] == iterationNumber,
      );

      if (historical != null) {
        final groups = historical['groups'] as List<dynamic>? ?? [];

        final Map<String, Map<String, dynamic>> historicalExecutor = {};
        final Map<String, Map<String, dynamic>> historicalReviewer = {};
        final Map<String, String?> historicalCategories = {};
        final Map<String, String?> historicalSeverities = {};

        // Helper to extract question answers from a flattened question list or groups
        void processQuestions(List<dynamic> qs) {
          for (final q in qs) {
            if (q is! Map<String, dynamic>) continue;
            final id = (q['_id'] ?? q['id'] ?? q['text'] ?? '').toString();
            if (id.isEmpty) continue;

            historicalExecutor[id] = {
              'answer': q['executorAnswer'],
              'remark': q['executorRemark'] ?? '',
              'images': q['executorImages'] ?? [],
            };

            historicalReviewer[id] = {
              'answer': q['reviewerAnswer'],
              'remark': q['reviewerRemark'] ?? '',
              'images': q['reviewerImages'] ?? [],
            };

            historicalCategories[id] = (q['categoryId'] ?? '').toString();
            final severity = (q['severity'] ?? '').toString();
            historicalSeverities[id] = severity.isEmpty ? null : severity;
          }
        }

        for (final group in groups) {
          if (group is! Map<String, dynamic>) continue;
          processQuestions(group['questions'] as List<dynamic>? ?? []);

          final sections = group['sections'] as List<dynamic>? ?? [];
          for (final section in sections) {
            if (section is! Map<String, dynamic>) continue;
            processQuestions(section['questions'] as List<dynamic>? ?? []);
          }
        }

        setState(() {
          executorAnswers.clear();
          executorAnswers.addAll(historicalExecutor);
          reviewerAnswers.clear();
          reviewerAnswers.addAll(historicalReviewer);
          _selectedDefectCategory.clear();
          _selectedDefectCategory.addAll(historicalCategories);
          _selectedDefectSeverity.clear();
          _selectedDefectSeverity.addAll(historicalSeverities);
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      debugPrint('Error swapping iteration: $e');
      setState(() => _isLoadingData = false);
    }
  }

  bool _areAnswersDifferent(dynamic ans1, dynamic ans2) {
    if (ans1 == ans2) return false;
    if (ans1 == null || ans2 == null) return true;
    final s1 = (ans1.toString()).trim().toLowerCase();
    final s2 = (ans2.toString()).trim().toLowerCase();
    return s1 != s2;
  }

  void _recomputeDefects() {
    // Compute defects locally from current answers - much simpler and more reliable
    final counts = <String, int>{};
    final checkpointCounts = <String, int>{};
    int total = 0;
    int totalCheckpoints = 0;

    for (final q in checklist) {
      final checklistId = q.checklistId ?? '';
      int defectCount = 0;
      final subs = q.subQuestions;
      final checkpointCount = subs.length;

      for (final sub in subs) {
        final textKey = (sub['text'] ?? '').toString();
        final idKey = (sub['id'] ?? '').toString();

        // Try text key first, then id key
        var execAnswer = executorAnswers[textKey]?['answer'];
        var reviAnswer = reviewerAnswers[textKey]?['answer'];

        if (execAnswer == null && idKey.isNotEmpty) {
          execAnswer = executorAnswers[idKey]?['answer'];
          reviAnswer = reviewerAnswers[idKey]?['answer'];
        }

        // Count as defect only if both have answered and answers differ (normalized)
        if (execAnswer != null &&
            reviAnswer != null &&
            _areAnswersDifferent(execAnswer, reviAnswer)) {
          defectCount++;
        }
      }

      counts[checklistId] = defectCount;
      checkpointCounts[checklistId] = checkpointCount;
      total += defectCount;
      totalCheckpoints += checkpointCount;
    }

    if (mounted) {
      setState(() {
        _defectsByChecklist = counts;
        _checkpointsByChecklist = checkpointCounts;
        // Track the highest defects seen in this session
        // Even if conflicts are fixed later, we remember the max we saw
        if (total > _maxDefectsSeenInSession) {
          _maxDefectsSeenInSession = total;
        }
        _totalCheckpointsInSession = totalCheckpoints;
      });
    }
  }

  /// Accumulate maximum defects from this session
  /// This ensures that even if conflicts are fixed before submission,
  /// the maximum defects encountered are still counted
  void _accumulateDefects() {
    if (_totalCheckpointsInSession > 0 && _maxDefectsSeenInSession > 0) {
      // Reset session tracking for next submission
      _maxDefectsSeenInSession = 0;
      _totalCheckpointsInSession = 0;
    }
  }

  Future<void> _computeActivePhase() async {
    final availablePhases =
        _availablePhaseNumbers.isEmpty
              ? <int>[1]
              : List<int>.from(_availablePhaseNumbers)
          ..sort();
    int active = availablePhases.first;
    bool allPhasesCompleted = false;
    try {
      // Fetch statuses for the actual available phases only
      // Force refresh to always get latest approval status
      final statusFutures = availablePhases
          .map(
            (phaseNum) => _approvalService
                .getStatus(widget.projectId, phaseNum, forceRefresh: true)
                .catchError((_) => null),
          )
          .toList();
      final statuses = await Future.wait(statusFutures);

      bool allApproved = true;
      for (int i = 0; i < statuses.length; i++) {
        final status = statuses[i];
        final phaseNum = availablePhases[i];
        if (status != null && status['status'] == 'approved') {
          // Move active phase to the next available phase.
          if (i + 1 < availablePhases.length) {
            active = availablePhases[i + 1];
          } else {
            active = phaseNum;
          }
        } else {
          active = phaseNum;
          allApproved = false;
          break;
        }
      }

      if (allApproved) {
        allPhasesCompleted = true;
        active = availablePhases.last;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isProjectCompleted = allPhasesCompleted;
      _activePhase = active;
      if (!_availablePhaseNumbers.contains(_selectedPhase)) {
        _selectedPhase = _activePhase;
      }
      final currentUserName = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value?.name
          : null;
      final isTeamLeader =
          currentUserName != null && authRoleIsTeamLeader(currentUserName);
      if (!isTeamLeader) {
        final selectedIndex = _availablePhaseNumbers.indexOf(_selectedPhase);
        final activeIndex = _availablePhaseNumbers.indexOf(_activePhase);
        if (selectedIndex > activeIndex && activeIndex >= 0) {
          _selectedPhase = _activePhase;
        }
      }
      if (_availablePhaseNumbers.isEmpty) {
        _selectedPhase = 1;
      } else if (!_availablePhaseNumbers.contains(_selectedPhase)) {
        _selectedPhase = _availablePhaseNumbers.first;
      }
    });
    // Refresh approval/compare for the currently selected phase in parallel with forced refresh
    // Also load revert counts for all phases to keep loopback counters updated
    final revertCountFutures = availablePhases
        .map(
          (phaseNum) => _approvalService
              .getRevertCount(widget.projectId, phaseNum, forceRefresh: true)
              .then((count) => MapEntry(phaseNum, count as int))
              .catchError((_) => MapEntry(phaseNum, 0)),
        )
        .toList();

    final revertResults = await Future.wait(revertCountFutures);

    if (mounted) {
      setState(() {
        for (final entry in revertResults) {
          _loopbackCounters[entry.key] = entry.value;
        }
      });
    }

    await Future.wait([
      _approvalService
          .compare(widget.projectId, _selectedPhase)
          .then((status) {
            if (mounted) setState(() => _compareStatus = status);
          })
          .catchError((_) {}),
      _approvalService
          .getStatus(widget.projectId, _selectedPhase, forceRefresh: true)
          .then((appr) {
            if (mounted) setState(() => _approvalStatus = appr);
          })
          .catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Determine current user role permissions from provided lists
    String? currentUserName;
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      currentUserName = auth.currentUser.value?.name;
    }
    // TeamLeader role: show approve/revert controls
    final isTeamLeader =
        currentUserName != null &&
        (authRoleIsTeamLeader(currentUserName) == true);
    final canEditExecutor =
        currentUserName != null &&
        widget.executors
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());
    final canEditReviewer =
        currentUserName != null &&
        widget.reviewers
            .map((e) => e.trim().toLowerCase())
            .contains(currentUserName.trim().toLowerCase());

    // Editing only allowed on active phase; older phases view-only for all
    // If project is completed, all phases are view-only
    // Special case: if phase is reverted, it becomes editable again
    final approvalStatus = _approvalStatus?['status'] as String?;
    final isReverted =
        approvalStatus == 'reverted' ||
        approvalStatus == 'reverted_to_executor';
    final phaseEditable =
        (_selectedPhase == _activePhase || isReverted) && !_isProjectCompleted;

    // Check if executor checklist for this phase has been submitted
    final executorSubmissionInfo = checklistCtrl.submissionInfo(
      widget.projectId,
      _selectedPhase,
      'executor',
    );
    final executorSubmitted = executorSubmissionInfo?['is_submitted'] == true;

    // Check if reviewer checklist for this phase has been submitted
    final reviewerSubmissionInfo = checklistCtrl.submissionInfo(
      widget.projectId,
      _selectedPhase,
      'reviewer',
    );
    final reviewerSubmitted = reviewerSubmissionInfo?['is_submitted'] == true;

    // Debug logging for submission status

    // Can edit only if phase is editable AND checklist has not been submitted
    // Special case: when reverted to executor, only executor can edit (reviewer stays submitted)
    final canEditExecutorPhase =
        canEditExecutor && phaseEditable && !executorSubmitted;
    final canEditReviewerPhase =
        canEditReviewer &&
        phaseEditable &&
        !reviewerSubmitted &&
        executorSubmitted && // Reviewer can only edit after executor submits
        approvalStatus !=
            'reverted_to_executor'; // Reviewer cannot edit when reverted to executor

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.projectTitle,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.blue,
        actions: [
          // TeamLeader can only view - no approve/revert buttons needed anymore
          // Reviewer submission now auto-approves the phase

          // Phase selector on the right
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedPhase,
              alignment: Alignment.center,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.expand_more, color: Colors.white),
              // Build UI phase list from actual stage keys present in project
              items: _availablePhaseNumbers.map((p) {
                // Get stage name from stageMap
                final stageKey = 'stage$p';
                final stageData = _stageMap[stageKey] as Map<String, dynamic>?;
                final stageName = stageData?['name'] ?? 'Phase $p';
                final pIndex = _availablePhaseNumbers.indexOf(p);
                final activeIndex = _availablePhaseNumbers.indexOf(
                  _activePhase,
                );

                return DropdownMenuItem(
                  value: p,
                  enabled: isTeamLeader
                      ? true
                      : (pIndex >= 0 && activeIndex >= 0
                            ? pIndex <= activeIndex
                            : false),
                  child: Row(
                    children: [
                      // Show actual stage name from template
                      Text(stageName),
                      const SizedBox(width: 8),
                      if (pIndex >= 0 &&
                          activeIndex >= 0 &&
                          pIndex < activeIndex)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'View only',
                            style: TextStyle(fontSize: 10),
                          ),
                        )
                      else if (p == _activePhase && !_isProjectCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(fontSize: 10),
                          ),
                        )
                      else if (_isProjectCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(fontSize: 10),
                          ),
                        )
                      else if (pIndex >= 0 &&
                          activeIndex >= 0 &&
                          pIndex > activeIndex &&
                          isTeamLeader)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) async {
                if (val == null) return;
                // TeamLeader can navigate to any phase for review
                // Others can only go up to active phase
                if (!isTeamLeader && val > _activePhase) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You can only proceed to the next phase after approval.',
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedPhase = val;
                });
                await _loadChecklistData();
              },
            ),
          ),
          // Refresh button on far right
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload checklist data',
            onPressed: _isLoadingData
                ? null
                : () async {
                    // Clear cache and reload
                    checklistCtrl.clearProjectCache(widget.projectId);
                    await _loadChecklistData();
                  },
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading checklist data...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Material(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage ?? '',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_approvalStatus != null || _compareStatus != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ApprovalBanner(
                        approvalStatus: _approvalStatus,
                        compareStatus: _compareStatus,
                      ),
                    ),
                  if (_isProjectCompleted)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Material(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Project Completed! All phases have been reviewed and approved. All phases are now in view-only mode.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Show reviewer submission summary for TeamLeader
                  if (isTeamLeader &&
                      _reviewerSubmissionSummaries[_selectedPhase] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ReviewerSubmissionSummaryCard(
                              summary:
                                  _reviewerSubmissionSummaries[_selectedPhase]!,
                              availableCategories: _getAvailableCategories(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_editMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _currentStageId == null
                                ? null
                                : () async {
                                    final nameCtrl = TextEditingController();
                                    final resp = await showDialog<String?>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('New checklist name'),
                                        content: TextField(
                                          controller: nameCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Checklist name',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(null),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              ctx,
                                            ).pop(nameCtrl.text.trim()),
                                            child: const Text('Create'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (resp != null && resp.isNotEmpty) {
                                      try {
                                        final svc =
                                            Get.find<PhaseChecklistService>();
                                        await svc.createForStage(
                                          _currentStageId!,
                                          name: resp,
                                        );
                                        await _loadChecklistData();
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Create failed: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Add checklist'),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit mode: changes apply immediately to this project',
                          ),
                        ],
                      ),
                    ),
                  // Show defect rate and loopback counter for all assigned users (executors, reviewers, and team leaders)
                  if (canEditExecutor || canEditReviewer || isTeamLeader)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Overall Defect Rate
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.assessment_outlined,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Overall Defect Rate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _overallDefectRate > 0
                                        ? Colors.blue
                                        : Colors.grey.shade600,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_overallDefectRate.toStringAsFixed(2)}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Defect Rate per Iteration
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.track_changes,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Defect Rate per Iteration',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Dropdown for iteration selection
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.shade300,
                                    ),
                                  ),
                                  child: DropdownButton<int>(
                                    value: _cachedDropdownItems.isEmpty
                                        ? null
                                        : _selectedIterationNumber,
                                    underline: const SizedBox(),
                                    isDense: true,
                                    items: _cachedDropdownItems.isNotEmpty
                                        ? _cachedDropdownItems
                                        : [
                                            const DropdownMenuItem<int>(
                                              value: null,
                                              child: Text(
                                                'No iterations',
                                                style: TextStyle(fontSize: 13),
                                              ),
                                            ),
                                          ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        _onIterationChanged(value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Display defect rate for selected iteration
                                Builder(
                                  builder: (context) {
                                    double defectRate = 0.0;
                                    if (_selectedIterationNumber != null) {
                                      // Check if it's current iteration
                                      if (_currentIterationStats != null &&
                                          _selectedIterationNumber ==
                                              _currentIterationStats!['iterationNumber']) {
                                        defectRate =
                                            (_currentIterationStats!['defectRate']
                                                    as num)
                                                .toDouble();
                                      } else {
                                        // Find in previous iterations
                                        final iter = _iterationsWithRates
                                            .firstWhere(
                                              (i) =>
                                                  i['iterationNumber'] ==
                                                  _selectedIterationNumber,
                                              orElse: () => {},
                                            );
                                        if (iter.isNotEmpty) {
                                          defectRate =
                                              (iter['defectRate'] as num)
                                                  .toDouble();
                                        }
                                      }
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: defectRate > 0
                                            ? Colors.orange
                                            : Colors.grey.shade600,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${defectRate.toStringAsFixed(2)}%',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Loopback Counter - visible to all assigned users
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.purple.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.loop,
                                  color: Colors.purple.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Loopback Counter',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_loopbackCounters[_selectedPhase] ?? 0}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        RoleColumn(
                          role: 'executor',
                          color: Colors.blue,
                          projectId: widget.projectId,
                          stageId: _currentStageId,
                          phase: _selectedPhase,
                          canEdit: canEditExecutorPhase,
                          checklist: checklist,
                          answers: executorAnswers,
                          otherAnswers: reviewerAnswers,
                          selectedDefectCategory: _selectedDefectCategory,
                          selectedDefectSeverity: _selectedDefectSeverity,
                          defectsByChecklist: _defectsByChecklist,
                          checkpointsByChecklist: _checkpointsByChecklist,
                          showDefects: isTeamLeader || canEditExecutor,
                          expanded: executorExpanded,
                          scrollController: _executorScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          getCategoryInfo: _getCategoryInfo,
                          availableCategories: _getAvailableCategories(),
                          onCategoryAssigned: _assignDefectCategory,
                          isCurrentUserReviewer:
                              false, // Executor column never shows revert button
                          onExpand: (idx) => setState(
                            () => executorExpanded.contains(idx)
                                ? executorExpanded.remove(idx)
                                : executorExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) async {
                            setState(() => executorAnswers[subQ] = ans);

                            // Save to checklist answers
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                              subQ,
                              ans,
                            );

                            // Also update the checkpoint with category and severity if available
                            // Use cached checkpoint ID map instead of looping through checklist
                            final checkpointId = _checkpointIdMap[subQ];

                            if (checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              final categoryId =
                                  _selectedDefectCategory[checkpointId];
                              final severity =
                                  _selectedDefectSeverity[checkpointId];

                              try {
                                final checklistService =
                                    Get.find<PhaseChecklistService>();
                                await checklistService.updateCheckpointResponse(
                                  checkpointId,
                                  executorResponse: {
                                    'answer': ans['answer'],
                                    'remark': ans['remark'] ?? '',
                                  },
                                  categoryId: categoryId,
                                  severity: severity,
                                );
                              } catch (e) {
                                // Silently ignore checkpoint update errors
                              }
                            }

                            _recomputeDefects();
                          },
                          onRevert:
                              null, // Executor should never see the revert button
                          onSubmit: () async {
                            if (!canEditExecutorPhase) return;
                            // Accumulate current defects before submission
                            _accumulateDefects();

                            // Submit executor checklist without showing dialog
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'executor',
                            );
                            if (success && mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Executor checklist submitted. Waiting for Reviewer to submit for phase approval.',
                                  ),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              await _computeActivePhase();
                            }
                          },
                          editMode: _editMode,
                          onRefresh: _loadChecklistData,
                          iterations: _historicalIterationsFull,
                        ),
                        RoleColumn(
                          role: 'reviewer',
                          color: Colors.green,
                          projectId: widget.projectId,
                          stageId: _currentStageId,
                          phase: _selectedPhase,
                          canEdit: canEditReviewerPhase,
                          checklist: checklist,
                          answers: reviewerAnswers,
                          otherAnswers: executorAnswers,
                          selectedDefectCategory: _selectedDefectCategory,
                          selectedDefectSeverity: _selectedDefectSeverity,
                          defectsByChecklist: _defectsByChecklist,
                          checkpointsByChecklist: _checkpointsByChecklist,
                          showDefects: isTeamLeader || canEditReviewer,
                          expanded: reviewerExpanded,
                          scrollController: _reviewerScroll,
                          highlightSubs: _highlightSubs,
                          checklistCtrl: checklistCtrl,
                          getCategoryInfo: _getCategoryInfo,
                          availableCategories: _getAvailableCategories(),
                          onCategoryAssigned: _assignDefectCategory,
                          isCurrentUserReviewer:
                              canEditReviewer &&
                              !canEditExecutor, // Only reviewers who are NOT executors
                          onExpand: (idx) => setState(
                            () => reviewerExpanded.contains(idx)
                                ? reviewerExpanded.remove(idx)
                                : reviewerExpanded.add(idx),
                          ),
                          onAnswer: (subQ, ans) async {
                            setState(() => reviewerAnswers[subQ] = ans);

                            // Use cached checkpoint ID map instead of looping through checklist
                            final checkpointId = _checkpointIdMap[subQ];

                            // Get category and severity from answer if provided, otherwise from maps
                            String? categoryId = (ans['categoryId'] ?? '')
                                .toString();
                            if (categoryId.isEmpty &&
                                checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              categoryId =
                                  _selectedDefectCategory[checkpointId];
                            }

                            String? severity = (ans['severity'] ?? '')
                                .toString();
                            if (severity.isEmpty &&
                                checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              severity = _selectedDefectSeverity[checkpointId];
                            }

                            // Update the maps with the current values
                            if (checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              if (categoryId != null && categoryId.isNotEmpty) {
                                _selectedDefectCategory[checkpointId] =
                                    categoryId;
                              }
                              if (severity != null && severity.isNotEmpty) {
                                _selectedDefectSeverity[checkpointId] =
                                    severity;
                              }
                            }

                            // Include category and severity in the answer for saving
                            final answerWithDefectInfo =
                                Map<String, dynamic>.from(ans);
                            if (categoryId != null && categoryId.isNotEmpty) {
                              answerWithDefectInfo['categoryId'] = categoryId;
                            }
                            if (severity != null && severity.isNotEmpty) {
                              answerWithDefectInfo['severity'] = severity;
                            }

                            // Save to checklist answers with category and severity
                            await checklistCtrl.setAnswer(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                              subQ,
                              answerWithDefectInfo,
                            );

                            // Also update the checkpoint with category and severity if available
                            if (checkpointId != null &&
                                checkpointId.isNotEmpty) {
                              try {
                                final checklistService =
                                    Get.find<PhaseChecklistService>();
                                await checklistService.updateCheckpointResponse(
                                  checkpointId,
                                  reviewerResponse: {
                                    'answer': ans['answer'],
                                    'remark': ans['remark'] ?? '',
                                  },
                                  categoryId: categoryId,
                                  severity: severity,
                                );
                              } catch (e) {}
                            }

                            _recomputeDefects();
                          },
                          // Only show revert button to actual reviewers
                          onRevert: canEditReviewer
                              ? _handleReviewerRevert
                              : null,
                          onSubmit: () async {
                            // Submit reviewer checklist without showing dialog
                            final success = await checklistCtrl.submitChecklist(
                              widget.projectId,
                              _selectedPhase,
                              'reviewer',
                            );
                            if (success && mounted) {
                              setState(() {});

                              // Wait a moment for auto-approval to process
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'âœ… Review submitted! Phase approved automatically. Next phase is now active.',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              await _computeActivePhase();

                              // Auto-switch to next phase if available
                              if (!_isProjectCompleted &&
                                  _activePhase <= _maxActualPhase) {
                                setState(() {
                                  _selectedPhase = _activePhase;
                                });
                                await _loadChecklistData();
                              }
                            }
                          },
                          editMode: _editMode,
                          onRefresh: _loadChecklistData,
                          iterations: _historicalIterationsFull,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool authRoleIsTeamLeader(String userName) {
    final u = userName.trim().toLowerCase();
    if (u.contains('teamleader')) return true;
    return widget.leaders.map((e) => e.trim().toLowerCase()).contains(u);
  }
}
