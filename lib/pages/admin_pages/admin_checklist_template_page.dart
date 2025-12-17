import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Admin Checklist Template Management Page
// - 3 phases (P1, P2, P3) with independent state
// - Manage Checklist Groups (add/edit/delete)
// - Manage Questions within each group (add/edit/delete)
// - Question has text, Yes/No radio preview, optional Remark field (preview-only)
// - Confirmation modals for deletions
// - JSON-based state structure prepared for backend integration later

class AdminChecklistTemplatePage extends StatefulWidget {
  const AdminChecklistTemplatePage({super.key});

  @override
  State<AdminChecklistTemplatePage> createState() =>
      _AdminChecklistTemplatePageState();
}

class _AdminChecklistTemplatePageState extends State<AdminChecklistTemplatePage>
    with SingleTickerProviderStateMixin {
  // Internal simple models kept local to this page for now
  // to keep scope frontend-only and reusable later with APIs.
  late final TabController _tabController;

  // Independent state per phase
  late List<TemplateGroup> _p1Groups;
  late List<TemplateGroup> _p2Groups;
  late List<TemplateGroup> _p3Groups;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Dummy starter data for P1, P2, P3
    _p1Groups = [
      TemplateGroup(
        id: _gid(),
        name: 'Verification',
        expanded: true,
        questions: [
          TemplateQuestion(
            id: _qid(),
            text: 'Are design inputs available?',
            hasRemark: true,
          ),
          TemplateQuestion(id: _qid(), text: 'CAD is up to date?'),
        ],
      ),
      TemplateGroup(
        id: _gid(),
        name: 'Geometry Preparation',
        questions: [
          TemplateQuestion(
            id: _qid(),
            text: 'Interference checks completed?',
            hasRemark: true,
          ),
        ],
      ),
    ];

    _p2Groups = [
      TemplateGroup(
        id: _gid(),
        name: 'Shell Mesh',
        expanded: true,
        questions: [
          TemplateQuestion(id: _qid(), text: 'Element quality within limits?'),
          TemplateQuestion(id: _qid(), text: 'Mesh density validated?'),
        ],
      ),
    ];

    _p3Groups = [
      TemplateGroup(
        id: _gid(),
        name: 'Post-Processing',
        questions: [
          TemplateQuestion(
            id: _qid(),
            text: 'Results reviewed by lead?',
            hasRemark: true,
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ID helpers (sufficient for local-only state)
  String _gid() => 'g_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}';
  String _qid() => 'q_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}';

  // Phase accessors
  List<TemplateGroup> _groupsForPhase(int index) {
    switch (index) {
      case 0:
        return _p1Groups;
      case 1:
        return _p2Groups;
      case 2:
      default:
        return _p3Groups;
    }
  }

  void _setGroupsForPhase(int index, List<TemplateGroup> groups) {
    setState(() {
      switch (index) {
        case 0:
          _p1Groups = groups;
          break;
        case 1:
          _p2Groups = groups;
          break;
        case 2:
        default:
          _p3Groups = groups;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Checklist Template Management',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Removed JSON preview per requirement

            // Phase tabs
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF2196F3),
                      unselectedLabelColor: Colors.black87,
                      indicatorColor: const Color(0xFF2196F3),
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Phase 1'),
                        Tab(text: 'Phase 2'),
                        Tab(text: 'Phase 3'),
                      ],
                    ),
                    SizedBox(
                      height: 12,
                      child: Container(
                        color: Colors.black12,
                        width: double.infinity,
                        height: 1,
                      ),
                    ),
                    // Fill remaining space with TabBarView to avoid overflow
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _PhaseEditor(
                            key: const ValueKey('phase-1'),
                            groups: _p1Groups,
                            onChanged: (g) => _setGroupsForPhase(0, g),
                          ),
                          _PhaseEditor(
                            key: const ValueKey('phase-2'),
                            groups: _p2Groups,
                            onChanged: (g) => _setGroupsForPhase(1, g),
                          ),
                          _PhaseEditor(
                            key: const ValueKey('phase-3'),
                            groups: _p3Groups,
                            onChanged: (g) => _setGroupsForPhase(2, g),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _phaseToJson(List<TemplateGroup> groups) {
    return {
      'phase': _tabController.index + 1,
      'groups': groups
          .map(
            (g) => {
              'id': g.id,
              'name': g.name,
              'questions': g.questions
                  .map(
                    (q) => {
                      'id': q.id,
                      'text': q.text,
                      'hasRemark': q.hasRemark,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }
}

class _PhaseEditor extends StatefulWidget {
  final List<TemplateGroup> groups;
  final ValueChanged<List<TemplateGroup>> onChanged;

  const _PhaseEditor({
    super.key,
    required this.groups,
    required this.onChanged,
  });

  @override
  State<_PhaseEditor> createState() => _PhaseEditorState();
}

class _PhaseEditorState extends State<_PhaseEditor> {
  late List<TemplateGroup> _groups;
  String _gid() => 'g_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}';

  @override
  void initState() {
    super.initState();
    _groups = widget.groups.map((g) => g.copy()).toList();
  }

  @override
  void didUpdateWidget(covariant _PhaseEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.groups, widget.groups)) {
      _groups = widget.groups.map((g) => g.copy()).toList();
    }
  }

  void _commit() => widget.onChanged(_groups.map((g) => g.copy()).toList());

  Future<void> _addGroup() async {
    final name = await _promptGroupName();
    if (name == null) return;
    setState(() {
      _groups.add(TemplateGroup(id: _gid(), name: name, expanded: true));
    });
    _commit();
  }

  Future<void> _editGroup(TemplateGroup group) async {
    final name = await _promptGroupName(initial: group.name);
    if (name == null) return;
    setState(() => group.name = name);
    _commit();
  }

  Future<void> _removeGroup(TemplateGroup group) async {
    final confirm = await _confirmDelete(
      title: 'Remove Checklist Group?',
      message: 'This will delete "${group.name}" and its questions.',
    );
    if (confirm != true) return;
    setState(() => _groups.removeWhere((g) => g.id == group.id));
    _commit();
  }

  Future<void> _addQuestion(TemplateGroup group) async {
    final q = await _promptQuestion();
    if (q == null) return;
    setState(() => group.questions.add(q));
    _commit();
  }

  Future<void> _editQuestion(
    TemplateGroup group,
    TemplateQuestion question,
  ) async {
    final updated = await _promptQuestion(initial: question);
    if (updated == null) return;
    setState(() {
      question.text = updated.text;
    });
    _commit();
  }

  Future<void> _removeQuestion(TemplateGroup group, TemplateQuestion q) async {
    final confirm = await _confirmDelete(
      title: 'Remove Question?',
      message: 'This will delete the selected question.',
    );
    if (confirm != true) return;
    setState(() => group.questions.removeWhere((x) => x.id == q.id));
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _addGroup,
              icon: const Icon(Icons.add),
              label: const Text('Add Checklist Group'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _groups.isEmpty
                ? _EmptyState(
                    title: 'No checklist groups yet',
                    subtitle: 'Click "Add Checklist Group" to create one.',
                  )
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, i) {
                      final group = _groups[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: group.expanded,
                          onExpansionChanged: (v) =>
                              setState(() => group.expanded = v),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          leading: const Icon(
                            Icons.view_list,
                            color: Color(0xFF2196F3),
                          ),
                          title: Text(
                            group.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 26,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit Group',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editGroup(group),
                              ),
                              IconButton(
                                tooltip: 'Delete Group',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeGroup(group),
                              ),
                            ],
                          ),
                          children: [
                            // Questions list
                            ...group.questions.map(
                              (q) => _QuestionRow(
                                question: q,
                                onEdit: () => _editQuestion(group, q),
                                onDelete: () => _removeQuestion(group, q),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _addQuestion(group),
                                style: TextButton.styleFrom(
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Question'),
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
}

// UI: Single question row with Yes/No preview radios and optional remark field (disabled preview)
class _QuestionRow extends StatelessWidget {
  final TemplateQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionRow({
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Edit Question',
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete Question',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
          // Remark preview removed per requirement
        ],
      ),
    );
  }
}

// Models (kept simple and local)
// Removed Yes/No preview state per requirement

class TemplateQuestion {
  TemplateQuestion({
    required this.id,
    required this.text,
    this.hasRemark = false,
    this.remarkHint,
  });

  final String id;
  String text;
  bool hasRemark;
  String? remarkHint;
  // PreviewAnswer removed

  TemplateQuestion copy() => TemplateQuestion(
    id: id,
    text: text,
    hasRemark: hasRemark,
    remarkHint: remarkHint,
  );
}

class TemplateGroup {
  TemplateGroup({
    required this.id,
    required this.name,
    this.questions = const [],
    this.expanded = false,
  });

  final String id;
  String name;
  List<TemplateQuestion> questions;
  bool expanded;

  TemplateGroup copy() => TemplateGroup(
    id: id,
    name: name,
    expanded: expanded,
    questions: questions.map((q) => q.copy()).toList(),
  );
}

// Dialogs & helpers
Future<String?> _promptGroupName({String? initial}) async {
  return await _textPrompt(
    title: initial == null ? 'Add Checklist Group' : 'Edit Checklist Group',
    label: 'Group Name',
    initial: initial,
  );
}

Future<TemplateQuestion?> _promptQuestion({TemplateQuestion? initial}) async {
  final text = await _textPrompt(
    title: initial == null ? 'Add Question' : 'Edit Question',
    label: 'Question Text',
    initial: initial?.text,
  );

  if (text == null) return null;

  return TemplateQuestion(
    id:
        initial?.id ??
        'q_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}',
    text: text,
  );
}

Future<String?> _textPrompt({
  required String title,
  required String label,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: Get.context!,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().isEmpty ? null : controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<bool?> _confirmDelete({
  required String title,
  required String message,
}) async {
  return showDialog<bool>(
    context: Get.context!,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirm({
  required String title,
  required String message,
  String confirmText = 'Yes',
  String cancelText = 'No',
}) async {
  return showDialog<bool>(
    context: Get.context!,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

class _JsonPreview extends StatelessWidget {
  final Map<String, dynamic> data;
  const _JsonPreview({required this.data});

  @override
  Widget build(BuildContext context) {
    final jsonText = const JsonEncoder.withIndent('  ').convert(data);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      title: const Text('JSON Preview (Current Phase)'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              jsonText,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}

// A very small empty state widget to keep consistent styling.
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// Uses Get.context to open dialogs without passing BuildContext around.
