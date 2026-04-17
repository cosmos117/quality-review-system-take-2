import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/template_models.dart';
import '../../controllers/admin_checklist_template_controller.dart';
import '../../components/shimmer_loading.dart';

class AdminChecklistTemplatePage
    extends GetView<AdminChecklistTemplateController> {
  const AdminChecklistTemplatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AdminChecklistTemplateController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Obx(() {
          if (c.isLoading.value) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerLoading(
                    child: SkeletonBox(width: 200, height: 24),
                  ),
                  const SizedBox(height: 16),
                  const SkeletonChecklistGroups(groupCount: 5),
                ],
              ),
            );
          }
          if (c.errorMessage.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    c.errorMessage.value!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: c.loadTemplate,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Checklist Template Management',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reload Template',
                          onPressed: () => c.loadTemplate(
                            templateName: c.selectedTemplateName.value,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onPressed: () async {
                            await Get.dialog(
                              _DefectCategoryManager(
                                categories: c.defectCategories.toList(),
                                controller: c,
                                onSave: (updated, groups) =>
                                    c.updateDefectCategories(
                                      updated,
                                      groups: groups,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.category),
                          label: const Text('Manage Defect Categories'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Template: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value:
                                        c.selectedTemplateName.value ??
                                        '__legacy__',
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '__legacy__',
                                        child: Text(
                                          'Default (legacy template)',
                                        ),
                                      ),
                                      ...c.templateOptions.map((t) {
                                        final templateName =
                                            (t['templateName'] ?? '')
                                                .toString();
                                        final displayName =
                                            (t['name'] ?? templateName)
                                                .toString();
                                        if (templateName.isEmpty) {
                                          return null;
                                        }
                                        return DropdownMenuItem<String>(
                                          value: templateName,
                                          child: Text(displayName),
                                        );
                                      }).whereType<DropdownMenuItem<String>>(),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        c.selectTemplate(
                                          value == '__legacy__' ? null : value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 220,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final name = await _promptTemplateName(
                                    context,
                                  );
                                  if (name != null) {
                                    await c.saveCurrentTemplateAs(name);
                                  }
                                },
                                icon: const Icon(Icons.save_as, size: 18),
                                label: const Text(
                                  'Save As New Template',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 180,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => c.saveSelectedTemplate(),
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('Save Template'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: c.selectedTemplateName.value == null
                              ? null
                              : () async {
                                  final confirm = await _confirmDelete(
                                    context: context,
                                    title: 'Delete Template?',
                                    message:
                                        'This will permanently delete the selected checklist template from the database.',
                                  );
                                  if (confirm == true) {
                                    await c.deleteSelectedTemplate();
                                  }
                                },
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Template'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Obx(() {
                  final visible = c.visiblePhaseIndexes;
                  if (visible.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2196F3),
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final name = await _promptStageName(
                                      context,
                                    );
                                    if (name != null) c.addPhase(name);
                                  },
                                  icon: const Icon(Icons.add, size: 22),
                                  label: const Text('Add Phase'),
                                ),
                              ],
                            ),
                            const Expanded(
                              child: Center(child: Text('No phases available')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Ensure current tab index is within bounds
                  if (c.currentTabIndex.value >= visible.length) {
                    c.currentTabIndex.value = 0;
                  }

                  return _PhaseTabView(visible: visible, controller: c);
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// Stateful widget to manage TabController properly
class _PhaseTabView extends StatefulWidget {
  final List<int> visible;
  final AdminChecklistTemplateController controller;

  const _PhaseTabView({required this.visible, required this.controller});

  @override
  State<_PhaseTabView> createState() => _PhaseTabViewState();
}

class _PhaseTabViewState extends State<_PhaseTabView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.visible.length,
      vsync: this,
      initialIndex: widget.controller.currentTabIndex.value.clamp(
        0,
        widget.visible.length - 1,
      ),
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(_PhaseTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible.length != widget.visible.length) {
      final newIndex = widget.controller.currentTabIndex.value.clamp(
        0,
        widget.visible.length - 1,
      );
      _tabController.removeListener(_handleTabChange);
      _tabController.dispose();
      _tabController = TabController(
        length: widget.visible.length,
        vsync: this,
        initialIndex: newIndex,
      );
      _tabController.addListener(_handleTabChange);
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      widget.controller.currentTabIndex.value = _tabController.index;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final visible = widget.visible;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF2196F3),
                    unselectedLabelColor: Colors.black87,
                    indicatorColor: const Color(0xFF2196F3),
                    isScrollable: true,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: visible.map((i) {
                      final phase = c.phases[i];
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(phase.name),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 16),
                              onSelected: (action) async {
                                if (action == 'delete') {
                                  final confirm = await _confirmDelete(
                                    context: context,
                                    title: 'Delete Phase?',
                                    message:
                                        'This will permanently delete "${phase.name}" and all its data. This action cannot be undone.',
                                  );
                                  if (confirm == true) c.deletePhase(phase);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    final name = await _promptStageName(context);
                    if (name != null) c.addPhase(name);
                  },
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text('Add Phase'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: visible.map((i) {
                final phase = c.phases[i];
                return PhaseEditor(phaseIndex: i, stage: phase.stage);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class PhaseEditor extends StatelessWidget {
  final int phaseIndex;
  final String stage;
  const PhaseEditor({super.key, required this.phaseIndex, required this.stage});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AdminChecklistTemplateController>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        final phase = c.phases[phaseIndex];
        final groups = phase.groups;
        return Column(
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
                onPressed: () async {
                  final name = await _promptGroupName(context);
                  if (name == null) return;
                  try {
                    await c.templateService.addChecklist(
                      templateName: c.selectedTemplateName.value,
                      stage: stage,
                      checklistName: name,
                    );
                    await c.loadTemplate(
                      templateName: c.selectedTemplateName.value,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      '$e',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Checklist Group'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: groups.isEmpty
                  ? const _EmptyState(
                      title: 'No checklist groups yet',
                      subtitle: 'Click "Add Checklist Group" to create one.',
                    )
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, i) {
                        final group = groups[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.black12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: group.expanded,
                            onExpansionChanged: (v) {
                              group.expanded = v;
                              c.refreshPhases();
                            },
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
                                  onPressed: () async {
                                    final name = await _promptGroupName(
                                      context,
                                      initial: group.name,
                                    );
                                    if (name == null) return;
                                    try {
                                      await c.templateService.updateChecklist(
                                        templateName:
                                            c.selectedTemplateName.value,
                                        checklistId: group.id,
                                        stage: stage,
                                        newName: name,
                                      );
                                      await c.loadTemplate(
                                        templateName:
                                            c.selectedTemplateName.value,
                                      );
                                    } catch (e) {
                                      Get.snackbar(
                                        'Error',
                                        '$e',
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete Group',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await _confirmDelete(
                                      context: context,
                                      title: 'Remove Checklist Group?',
                                      message:
                                          'This will delete "${group.name}" plus all its sections and questions.',
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await c.templateService.deleteChecklist(
                                        templateName:
                                            c.selectedTemplateName.value,
                                        checklistId: group.id,
                                        stage: stage,
                                      );
                                      await c.loadTemplate(
                                        templateName:
                                            c.selectedTemplateName.value,
                                      );
                                      Get.snackbar(
                                        'Deleted',
                                        'Checklist group "${group.name}" has been deleted',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.green,
                                        colorText: Colors.white,
                                      );
                                    } catch (e) {
                                      Get.snackbar(
                                        'Error',
                                        'Failed to delete: $e',
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            children: [
                              ...group.questions.map(
                                (q) => _QuestionRow(
                                  question: q,
                                  onEdit: () async {
                                    final updated = await _promptQuestion(
                                      context,
                                      initial: q,
                                    );
                                    if (updated == null) return;
                                    try {
                                      await c.templateService.updateCheckpoint(
                                        templateName:
                                            c.selectedTemplateName.value,
                                        checkpointId: q.id,
                                        checklistId: group.id,
                                        stage: stage,
                                        newText: updated.text,
                                      );
                                      await c.loadTemplate(
                                        templateName:
                                            c.selectedTemplateName.value,
                                      );
                                    } catch (e) {
                                      Get.snackbar(
                                        'Error',
                                        '$e',
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                  onDelete: () async {
                                    final confirm = await _confirmDelete(
                                      context: context,
                                      title: 'Remove Question?',
                                      message:
                                          'This will delete the selected question.',
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await c.templateService.deleteCheckpoint(
                                        templateName:
                                            c.selectedTemplateName.value,
                                        checkpointId: q.id,
                                        checklistId: group.id,
                                        stage: stage,
                                      );
                                      await c.loadTemplate(
                                        templateName:
                                            c.selectedTemplateName.value,
                                      );
                                    } catch (e) {
                                      Get.snackbar(
                                        'Error',
                                        '$e',
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                ),
                              ),
                              ...group.sections.map((section) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  color: Colors.grey[50],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Colors.black12,
                                      width: 1,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: section.expanded,
                                    onExpansionChanged: (v) {
                                      section.expanded = v;
                                      c.refreshPhases();
                                    },
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    childrenPadding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      12,
                                    ),
                                    title: Text(
                                      section.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit Section',
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
                                          onPressed: () async {
                                            final name =
                                                await _promptSectionName(
                                                  context,
                                                  initial: section.name,
                                                );
                                            if (name == null) return;
                                            try {
                                              await c.templateService
                                                  .updateSection(
                                                    templateName: c
                                                        .selectedTemplateName
                                                        .value,
                                                    checklistId: group.id,
                                                    sectionId: section.id,
                                                    stage: stage,
                                                    newName: name,
                                                  );
                                              await c.loadTemplate(
                                                templateName: c
                                                    .selectedTemplateName
                                                    .value,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                '$e',
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                            }
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete Section',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            final confirm = await _confirmDelete(
                                              context: context,
                                              title: 'Remove Section?',
                                              message:
                                                  'This will delete "${section.name}" and all its questions.',
                                            );
                                            if (confirm != true) return;
                                            try {
                                              await c.templateService
                                                  .deleteSection(
                                                    templateName: c
                                                        .selectedTemplateName
                                                        .value,
                                                    checklistId: group.id,
                                                    sectionId: section.id,
                                                    stage: stage,
                                                  );
                                              await c.loadTemplate(
                                                templateName: c
                                                    .selectedTemplateName
                                                    .value,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                '$e',
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                            }
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      ...section.questions.map((q) {
                                        return _QuestionRow(
                                          question: q,
                                          onEdit: () async {
                                            final updated =
                                                await _promptQuestion(
                                                  context,
                                                  initial: q,
                                                );
                                            if (updated == null) return;
                                            try {
                                              await c.templateService
                                                  .updateCheckpoint(
                                                    templateName: c
                                                        .selectedTemplateName
                                                        .value,
                                                    checkpointId: q.id,
                                                    checklistId: group.id,
                                                    stage: stage,
                                                    newText: updated.text,
                                                    sectionId: section.id,
                                                  );
                                              await c.loadTemplate(
                                                templateName: c
                                                    .selectedTemplateName
                                                    .value,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                '$e',
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                            }
                                          },
                                          onDelete: () async {
                                            final confirm = await _confirmDelete(
                                              context: context,
                                              title: 'Remove Question?',
                                              message:
                                                  'This will delete the selected question.',
                                            );
                                            if (confirm != true) return;
                                            try {
                                              await c.templateService
                                                  .deleteCheckpoint(
                                                    templateName: c
                                                        .selectedTemplateName
                                                        .value,
                                                    checkpointId: q.id,
                                                    checklistId: group.id,
                                                    stage: stage,
                                                    sectionId: section.id,
                                                  );
                                              await c.loadTemplate(
                                                templateName: c
                                                    .selectedTemplateName
                                                    .value,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                '$e',
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                            }
                                          },
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () async {
                                            final q = await _promptQuestion(
                                              context,
                                            );
                                            if (q == null) return;
                                            try {
                                              await c.templateService
                                                  .addCheckpoint(
                                                    templateName: c
                                                        .selectedTemplateName
                                                        .value,
                                                    checklistId: group.id,
                                                    stage: stage,
                                                    questionText: q.text,
                                                    sectionId: section.id,
                                                  );
                                              await c.loadTemplate(
                                                templateName: c
                                                    .selectedTemplateName
                                                    .value,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                '$e',
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                            }
                                          },
                                          style: TextButton.styleFrom(
                                            textStyle: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add Question'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final q = await _promptQuestion(context);
                                      if (q == null) return;
                                      try {
                                        await c.templateService.addCheckpoint(
                                          templateName:
                                              c.selectedTemplateName.value,
                                          checklistId: group.id,
                                          stage: stage,
                                          questionText: q.text,
                                        );
                                        await c.loadTemplate(
                                          templateName:
                                              c.selectedTemplateName.value,
                                        );
                                      } catch (e) {
                                        Get.snackbar(
                                          'Error',
                                          '$e',
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      textStyle: const TextStyle(fontSize: 14),
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Question'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final name = await _promptSectionName(
                                        context,
                                      );
                                      if (name == null) return;
                                      try {
                                        await c.templateService.addSection(
                                          templateName:
                                              c.selectedTemplateName.value,
                                          checklistId: group.id,
                                          stage: stage,
                                          sectionName: name,
                                        );
                                        await c.loadTemplate(
                                          templateName:
                                              c.selectedTemplateName.value,
                                        );
                                      } catch (e) {
                                        Get.snackbar(
                                          'Error',
                                          '$e',
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      textStyle: const TextStyle(fontSize: 14),
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Section'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }
}

// Simple row for a question
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
      child: Row(
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
    );
  }
}

// Dialogs & helpers
Future<String?> _promptGroupName(
  BuildContext context, {
  String? initial,
}) async {
  return await _textPrompt(
    context: context,
    title: initial == null ? 'Add Checklist Group' : 'Edit Checklist Group',
    label: 'Group Name',
    initial: initial,
  );
}

Future<TemplateQuestion?> _promptQuestion(
  BuildContext context, {
  TemplateQuestion? initial,
}) async {
  return await showDialog<TemplateQuestion>(
    context: context,
    builder: (ctx) => _QuestionDialog(initial: initial),
  );
}

Future<String?> _promptSectionName(
  BuildContext context, {
  String? initial,
}) async {
  return await _textPrompt(
    context: context,
    title: initial == null ? 'Add Section' : 'Edit Section',
    label: 'Section Name',
    initial: initial,
  );
}

Future<String?> _promptStageName(BuildContext context) async {
  return await _textPrompt(
    context: context,
    title: 'Add New Stage',
    label: 'Stage Name (e.g., Planning, Design, Testing)',
  );
}

Future<String?> _promptTemplateName(BuildContext context) async {
  return await _textPrompt(
    context: context,
    title: 'Save Template',
    label: 'Template Name (e.g., FEA Checklist, CFM Checklist)',
  );
}

Future<String?> _textPrompt({
  required BuildContext context,
  required String title,
  required String label,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  const dialogWidth = 460.0;
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
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
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return showDialog<bool>(
    context: context,
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

class _QuestionDialog extends StatefulWidget {
  final TemplateQuestion? initial;
  const _QuestionDialog({this.initial});
  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController _textController;
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initial?.text ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Question' : 'Edit Question'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isEmpty) {
              Navigator.pop(context);
              return;
            }
            final question = TemplateQuestion(
              id:
                  widget.initial?.id ??
                  'q_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey()}',
              text: text,
            );
            Navigator.pop(context, question);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

List<DefectCategory> _getDefaultDefectCategories() {
  return [
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_1',
      name: 'Incorrect Modelling Strategy - Geometry',
      keywords: [
        'geometry',
        'modelling',
        'model',
        'incorrect strategy',
        'geometric',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_2',
      name: 'Incorrect Modelling Strategy - Material',
      keywords: [
        'material',
        'modelling',
        'properties',
        'material properties',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_3',
      name: 'Incorrect Modelling Strategy - Loads',
      keywords: [
        'loads',
        'loading',
        'force',
        'boundary condition',
        'load case',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_4',
      name: 'Incorrect Modelling Strategy - BC',
      keywords: ['bc', 'boundary condition', 'constraint', 'support', 'fixed'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_5',
      name: 'Incorrect Modelling Strategy - Assumptions',
      keywords: [
        'assumptions',
        'assumption',
        'simplification',
        'unclear',
        'not documented',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_6',
      name: 'Incorrect Modelling Strategy - Acceptance Criteria',
      keywords: [
        'acceptance',
        'criteria',
        'acceptance criteria',
        'requirements',
        'specification',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_7',
      name: 'Incorrect geometry units',
      keywords: ['units', 'geometry units', 'mm', 'cm', 'meter', 'measurement'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_8',
      name: 'Incorrect meshing',
      keywords: ['meshing', 'mesh', 'element', 'discretization', 'refinement'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_9',
      name: 'Defective mesh quality',
      keywords: [
        'mesh quality',
        'defective',
        'aspect ratio',
        'distorted',
        'poor quality',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_10',
      name: 'Incorrect contact definition',
      keywords: [
        'contact',
        'contact definition',
        'interface',
        'interaction',
        'friction',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_11',
      name: 'Incorrect beam/bolt modeling',
      keywords: ['beam', 'bolt', 'modeling', 'connection', 'fastener'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_12',
      name: 'RBE/RBE3 are not modeled properly',
      keywords: ['rbe', 'rbe3', 'rigid element', 'constraint', 'coupling'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_13',
      name: 'Incorrect loads and Boundary Condition',
      keywords: [
        'loads',
        'boundary condition',
        'load application',
        'force',
        'constraint',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_14',
      name: 'Incorrect connectivity',
      keywords: [
        'connectivity',
        'nodes',
        'element connectivity',
        'connection',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_15',
      name: 'Incorrect degree of element order',
      keywords: [
        'degree of element',
        'order',
        'linear',
        'quadratic',
        'polynomial',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_16',
      name: 'Incorrect element quality',
      keywords: [
        'element quality',
        'distorted',
        'skewed',
        'aspect ratio',
        'defective',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_17',
      name: 'Incorrect bolt size',
      keywords: ['bolt', 'size', 'diameter', 'incorrect', 'dimension'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_18',
      name: 'Incorrect elements order',
      keywords: ['elements', 'order', 'sequence', 'incorrect', 'wrong'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_19',
      name: 'Incorrect elements quality',
      keywords: ['elements', 'quality', 'poor', 'defective', 'invalid'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_20',
      name: 'Incorrect end loads',
      keywords: ['end loads', 'terminal loads', 'force', 'moment', 'incorrect'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_21',
      name: 'Too refined mesh at the non critical regions',
      keywords: [
        'refined mesh',
        'over meshing',
        'unnecessary refinement',
        'non critical',
        'wasteful',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_22',
      name: 'Support Gap',
      keywords: [
        'support',
        'gap',
        'missing support',
        'incomplete support',
        'void',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_23',
      name: 'Support Location',
      keywords: [
        'support',
        'location',
        'positioning',
        'placement',
        'incorrect position',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_24',
      name: 'Incorrect Scope',
      keywords: ['scope', 'boundary', 'region', 'area', 'out of scope'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_25',
      name: 'free pages',
      keywords: ['free pages', 'blank pages', 'empty', 'unneeded'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_26',
      name: 'Incorrect mass modeling',
      keywords: ['mass', 'mass modeling', 'density', 'weight', 'incorrect'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_27',
      name: 'Incorrect material properties',
      keywords: [
        'material',
        'properties',
        'young modulus',
        'poisson',
        'density',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_28',
      name: 'Incorrect global output request',
      keywords: [
        'global output',
        'output request',
        'results request',
        'missing output',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_29',
      name: 'Incorrect loadstep creation',
      keywords: [
        'loadstep',
        'load step',
        'step creation',
        'load case',
        'step definition',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_30',
      name: 'Incorrect output request',
      keywords: ['output', 'request', 'results', 'incorrect', 'missing'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_31',
      name: 'Incorrect Interpretation',
      keywords: [
        'interpretation',
        'analysis',
        'conclusion',
        'incorrect',
        'misunderstood',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_32',
      name: 'Incorrect Results location and Values',
      keywords: [
        'results',
        'values',
        'location',
        'incorrect',
        'wrong',
        'mismatch',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_33',
      name: 'Incorrect Observation',
      keywords: ['observation', 'comment', 'note', 'incorrect', 'inaccurate'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_34',
      name: 'Incorrect Naming',
      keywords: ['naming', 'name', 'label', 'title', 'incorrect', 'misspelled'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_35',
      name: 'Missing Results Plot',
      keywords: ['results', 'plot', 'graph', 'chart', 'missing', 'absent'],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_36',
      name: 'Incomplete conclusion, suggestions',
      keywords: [
        'conclusion',
        'suggestions',
        'incomplete',
        'missing',
        'recommendations',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_37',
      name: 'Template not followed',
      keywords: [
        'template',
        'followed',
        'not followed',
        'deviation',
        'non compliance',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_38',
      name: 'Checklist not followed',
      keywords: [
        'checklist',
        'followed',
        'not followed',
        'incomplete',
        'skipped',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_39',
      name: 'Planning sheet not followed',
      keywords: [
        'planning sheet',
        'plan',
        'not followed',
        'deviation',
        'unplanned',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_40',
      name: 'Folder Structure not followed',
      keywords: [
        'folder structure',
        'directory',
        'organization',
        'not followed',
        'incorrect',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_41',
      name: 'Name/revision report incorrect',
      keywords: [
        'name',
        'revision',
        'report',
        'incorrect',
        'wrong',
        'mismatch',
      ],
    ),
    DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_42',
      name: 'Typo Textual Error',
      keywords: ['typo', 'spelling', 'grammar', 'text', 'error', 'mistake'],
    ),
  ];
}

class _DefectCategoryManager extends StatefulWidget {
  final List<DefectCategory> categories;
  final AdminChecklistTemplateController controller;
  final Future<void> Function(List<DefectCategory>, List<String>) onSave;

  const _DefectCategoryManager({
    required this.categories,
    required this.controller,
    required this.onSave,
  });

  @override
  State<_DefectCategoryManager> createState() => _DefectCategoryManagerState();
}

class _DefectCategoryManagerState extends State<_DefectCategoryManager>
    with SingleTickerProviderStateMixin {
  late List<DefectCategory> _categories;
  bool _isSaving = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Category Groups tab state
  late TabController _tabController;
  String? _selectedGroup; // which group is shown in the right panel

  // colours
  static const Color _blue = Color(0xFF2196F3);
  static const Color _divider = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _categories = widget.categories.map((c) => c.copy()).toList();
    _pendingEmptyGroups.addAll(widget.controller.defectCategoryGroups);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // helpers
  List<String> get _groups {
    final s = _categories.map((c) => c.group).toSet().toList()..sort();
    return s;
  }

  List<String> _autoKeywords(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[-/\\]'), ' ')
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.length > 1)
      .toSet()
      .toList();

  String _normalizeCategoryName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  bool _isDuplicateCategoryName(String value, {String? excludeId}) {
    final normalized = _normalizeCategoryName(value);
    if (normalized.isEmpty) {
      return false;
    }

    return _categories.any((category) {
      if (excludeId != null && category.id == excludeId) {
        return false;
      }
      return _normalizeCategoryName(category.name) == normalized;
    });
  }

  List<DefectCategory> _dedupeCategoriesByName(
    List<DefectCategory> categories,
  ) {
    final seen = <String>{};
    final deduped = <DefectCategory>[];

    for (final category in categories) {
      final cleanedName = category.name.trim().replaceAll(RegExp(r'\s+'), ' ');
      final normalized = _normalizeCategoryName(cleanedName);
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }

      seen.add(normalized);
      category.name = cleanedName;
      category.group = category.group.trim().isEmpty
          ? 'General'
          : category.group.trim();
      deduped.add(category);
    }

    return deduped;
  }

  void _showDuplicateCategoryMessage(String categoryName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Category "$categoryName" already exists. Use a unique name.',
        ),
      ),
    );
  }

  // dialogs
  Future<String?> _promptGroupName({String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'New Group' : 'Rename Group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Modelling Strategy',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewCategory({required String initialGroup}) async {
    final nameCtrl = TextEditingController();
    String currentGroup = initialGroup;
    String? nameValidationError;
    final groups = _allGroupNames(_groups); // helper getter

    final cat = await showDialog<DefectCategory>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final kws = _autoKeywords(nameCtrl.text);
          return AlertDialog(
            title: const Text('Add New Category'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    onChanged: (_) {
                      setSt(() {
                        nameValidationError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Category name',
                      hintText: 'e.g. Incorrect Meshing',
                      border: OutlineInputBorder(),
                      isDense: true,
                      errorText: nameValidationError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: groups.contains(currentGroup)
                        ? currentGroup
                        : (groups.isNotEmpty ? groups.first : 'General'),
                    decoration: const InputDecoration(
                      labelText: 'Group',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      ...groups.map(
                        (g) => DropdownMenuItem(value: g, child: Text(g)),
                      ),
                      if (!groups.contains('General'))
                        const DropdownMenuItem(
                          value: 'General',
                          child: Text('General'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => currentGroup = v);
                    },
                  ),
                  if (nameCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Keywords (auto-generated):',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: kws
                          .map(
                            (k) => Chip(
                              label: Text(
                                k,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: _blue.withValues(alpha: 0.1),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
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
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim().replaceAll(
                    RegExp(r'\s+'),
                    ' ',
                  );
                  if (name.isEmpty) {
                    setSt(() {
                      nameValidationError = 'Category name is required.';
                    });
                    return;
                  }

                  if (_isDuplicateCategoryName(name)) {
                    setSt(() {
                      nameValidationError =
                          'Category "$name" already exists. Use a unique name.';
                    });
                    return;
                  }

                  Navigator.pop(
                    ctx,
                    DefectCategory(
                      id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
                      name: name,
                      group: currentGroup,
                      keywords: _autoKeywords(name),
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    if (cat != null) setState(() => _categories.add(cat));
  }

  /// Let the user pick from master list to assign to a group
  Future<void> _addExistingToGroup(String group) async {
    final notInGroup = _categories.where((c) => c.group != group).toList();
    if (notInGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All categories are already in this group.'),
        ),
      );
      return;
    }

    final searchCtrl = TextEditingController();
    String searchQuery = '';
    final picked = await showDialog<List<DefectCategory>>(
      context: context,
      builder: (ctx) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final query = searchQuery.trim().toLowerCase();
            final filtered = notInGroup
                .where(
                  (c) =>
                      query.isEmpty ||
                      c.name.toLowerCase().contains(query) ||
                      c.group.toLowerCase().contains(query),
                )
                .toList();

            return AlertDialog(
              title: const Text('Add Existing Categories'),
              content: SizedBox(
                width: 440,
                height: 440,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      onChanged: (value) {
                        setSt(() => searchQuery = value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search categories...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No categories found for this search.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView(
                              children: filtered
                                  .map(
                                    (c) => CheckboxListTile(
                                      title: Text(c.name),
                                      subtitle: Text(
                                        'Currently: ${c.group}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      value: selected.contains(c.id),
                                      onChanged: (v) => setSt(
                                        () => v!
                                            ? selected.add(c.id)
                                            : selected.remove(c.id),
                                      ),
                                    ),
                                  )
                                  .toList(),
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
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(
                    ctx,
                    notInGroup.where((c) => selected.contains(c.id)).toList(),
                  ),
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );
    searchCtrl.dispose();

    if (picked != null && picked.isNotEmpty) {
      setState(() {
        for (final c in picked) {
          c.group = group;
        }
      });
    }
  }

  Future<void> _editCategory(DefectCategory cat) async {
    final nameCtrl = TextEditingController(text: cat.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Category name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final updatedName = nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (_isDuplicateCategoryName(updatedName, excludeId: cat.id)) {
        _showDuplicateCategoryMessage(updatedName);
        return;
      }

      setState(() {
        cat.name = updatedName;
        cat.keywords = _autoKeywords(cat.name);
      });
    }
  }

  void _deleteCategory(DefectCategory cat) {
    setState(() => _categories.remove(cat));
  }

  void _loadDefaultCategories() {
    setState(() {
      _categories = _getDefaultDefectCategories();
      _selectedGroup = null;
    });
  }

  // Master categories tab
  Widget _buildMasterTab() {
    final q = _searchQuery;
    final filtered = _categories
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.group.toLowerCase().contains(q),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add button row
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_categories.isEmpty)
                TextButton.icon(
                  onPressed: _loadDefaultCategories,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Load Defaults'),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _addNewCategory(initialGroup: 'General'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Category'),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    q.isEmpty
                        ? 'No categories yet. Click "Add New Category" or "Load Defaults".'
                        : 'No results for "$q".',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _divider),
                  itemBuilder: (_, i) {
                    final cat = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        cat.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        cat.group,
                        style: TextStyle(
                          fontSize: 11,
                          color: _blue.withValues(alpha: 0.8),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: Colors.grey,
                            ),
                            tooltip: 'Edit',
                            onPressed: () => _editCategory(cat),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 17,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => _deleteCategory(cat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Category Groups tab
  Widget _buildGroupsTab() {
    final groups = _groups;
    // select first group by default
    if (_selectedGroup == null && groups.isNotEmpty) {
      _selectedGroup = groups.first;
    }
    final allGroupsForSearch = _allGroupNames(groups);
    if (_selectedGroup != null &&
        !allGroupsForSearch.contains(_selectedGroup)) {
      _selectedGroup = allGroupsForSearch.isNotEmpty
          ? allGroupsForSearch.first
          : null;
    }

    final q = _searchQuery;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel: group list
        Container(
          width: 230,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Category Groups',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () async {
                        final name = await _promptGroupName();
                        if (name != null) {
                          setState(() {
                            // Create a placeholder category so the group appears
                            // (groups are derived from categories, so we need at least one)
                            _selectedGroup = name;
                            // We don't auto-create a category; the group shows as empty
                            // until the user adds one from the right panel.
                            // We track "pending empty groups" with a ghost set.
                            _pendingEmptyGroups.add(name);
                          });
                        }
                      },
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _divider),
              // Group items
              Expanded(
                child: ListView(
                  children: [
                    ..._allGroupNames(groups).map((g) {
                      final count = _categories
                          .where((c) => c.group == g)
                          .length;
                      final isSelected = _selectedGroup == g;
                      final matchesSearch =
                          q.isEmpty ||
                          g.toLowerCase().contains(q) ||
                          _categories.any(
                            (c) =>
                                c.group == g &&
                                c.name.toLowerCase().contains(q),
                          );
                      if (!matchesSearch) return const SizedBox.shrink();
                      return InkWell(
                        onTap: () => setState(() => _selectedGroup = g),
                        child: Container(
                          color: isSelected
                              ? _blue.withValues(alpha: 0.07)
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? _blue
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '$count ${count == 1 ? "category" : "categories"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete Group',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'rename') {
                                    final newName = await _promptGroupName(
                                      initial: g,
                                    );
                                    if (newName != null && newName != g) {
                                      setState(() {
                                        for (final c in _categories) {
                                          if (c.group == g) c.group = newName;
                                        }
                                        _pendingEmptyGroups.remove(g);
                                        _pendingEmptyGroups.remove(newName);
                                        if (_selectedGroup == g)
                                          _selectedGroup = newName;
                                      });
                                    }
                                  } else if (action == 'delete') {
                                    final catCount = _categories
                                        .where((c) => c.group == g)
                                        .length;
                                    String? deleteAction;

                                    if (catCount > 0) {
                                      deleteAction = await showDialog<String>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Group'),
                                          content: Text(
                                            'This group contains $catCount category(ies). What would you like to do?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, 'move'),
                                              child: const Text(
                                                'Move to General',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, 'delete'),
                                              child: const Text(
                                                'Delete All',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      // Empty group, just delete
                                      deleteAction = 'delete';
                                    }

                                    if (deleteAction == 'move') {
                                      setState(() {
                                        for (final c in _categories) {
                                          if (c.group == g) c.group = 'General';
                                        }
                                        _pendingEmptyGroups.remove(g);
                                        if (_selectedGroup == g)
                                          _selectedGroup = null;
                                      });
                                    } else if (deleteAction == 'delete') {
                                      setState(() {
                                        _categories.removeWhere(
                                          (c) => c.group == g,
                                        );
                                        _pendingEmptyGroups.remove(g);
                                        if (_selectedGroup == g)
                                          _selectedGroup = null;
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right panel: categories inside selected group
        Expanded(
          child: _selectedGroup == null
              ? const Center(
                  child: Text(
                    'Select or create a group',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : _buildGroupDetail(_selectedGroup!, q),
        ),
      ],
    );
  }

  Widget _buildGroupDetail(String group, String q) {
    final inGroup =
        _categories.where((c) {
          if (c.group != group) return false;
          if (q.isNotEmpty && !c.name.toLowerCase().contains(q)) return false;
          return true;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Right panel header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Text(
                group,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Add Existing
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _addExistingToGroup(group),
                icon: const Icon(Icons.dynamic_feed_rounded, size: 16),
                label: const Text('Add Existing'),
              ),
              const SizedBox(width: 8),
              // Add New
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _addNewCategory(initialGroup: _selectedGroup!),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New Category'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _divider),
        // Category list in group
        Expanded(
          child: inGroup.isEmpty
              ? const Center(
                  child: Text(
                    'No categories in this group yet.\nAdd or move categories here using the buttons above.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: inGroup.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _divider),
                  itemBuilder: (_, i) {
                    final cat = inGroup[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        cat.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: Colors.grey,
                            ),
                            tooltip: 'Edit',
                            onPressed: () => _editCategory(cat),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 17,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Delete Category',
                            onPressed: () => _deleteCategory(cat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Track groups that have no categories yet (user created but hasn't added to)
  final Set<String> _pendingEmptyGroups = {};

  List<String> _allGroupNames(List<String> categoriesGroups) {
    final all = {...categoriesGroups, ..._pendingEmptyGroups}.toList()..sort();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final isGroupsTab = _tabController.index == 1;
    final searchHint = isGroupsTab
        ? 'Search groups and grouped categories'
        : 'Search master categories...';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: SizedBox(
        width: 960,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Manage Defect Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Master Categories'),
                Tab(text: 'Category Groups'),
              ],
              labelColor: _blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _blue,
              indicatorWeight: 2.5,
            ),
            const Divider(height: 1, color: _divider),

            // Search bar (shared)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _blue, width: 1.5),
                  ),
                ),
              ),
            ),

            // Tab content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildMasterTab(), _buildGroupsTab()],
                ),
              ),
            ),

            // Bottom action bar
            const Divider(height: 1, color: _divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_categories.isEmpty)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _loadDefaultCategories,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Load Defaults'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            try {
                              final dedupedCategories = _dedupeCategoriesByName(
                                _categories,
                              );
                              if (dedupedCategories.length !=
                                  _categories.length) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Duplicate category names were removed before saving.',
                                    ),
                                  ),
                                );
                              }

                              setState(() => _categories = dedupedCategories);
                              final categoryGroups =
                                  dedupedCategories
                                      .map((category) => category.group)
                                      .toSet()
                                      .toList()
                                    ..sort();
                              final allGroups = _allGroupNames(categoryGroups);

                              await widget.onSave(dedupedCategories, allGroups);
                              if (mounted) Navigator.pop(context);
                            } finally {
                              if (mounted) setState(() => _isSaving = false);
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
