import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/template_models.dart';
import '../services/template_service.dart';

class AdminChecklistTemplateController extends GetxController {
  final TemplateService templateService = Get.find<TemplateService>();

  final phases = <PhaseModel>[].obs;
  final defectCategories = <DefectCategory>[].obs;
  final templateOptions = <Map<String, dynamic>>[].obs;
  final selectedTemplateName = RxnString();
  final isLoading = true.obs;
  final errorMessage = RxnString();
  Map<String, dynamic> _templateData = {};

  // Track expansion states to preserve them across reloads
  final Map<String, bool> _groupExpansionStates = {};
  final Map<String, bool> _sectionExpansionStates = {};

  // Track current tab index to preserve it across reloads
  final RxInt currentTabIndex = 0.obs;

  // Show all phase tabs
  List<int> get visiblePhaseIndexes => List.generate(phases.length, (i) => i);

  @override
  void onInit() {
    super.onInit();
    initializeTemplateLibrary();
  }

  Future<void> initializeTemplateLibrary() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final names = await templateService.fetchTemplateNames(
        forceRefresh: true,
      );
      templateOptions.value = names;

      if (names.isNotEmpty) {
        final initial = (names.first['templateName'] ?? '').toString();
        selectedTemplateName.value = initial.isEmpty ? null : initial;
      } else {
        selectedTemplateName.value = null;
      }

      await loadTemplate(templateName: selectedTemplateName.value);
    } catch (e) {
      // Fall back to legacy singleton template if library lookup fails.
      selectedTemplateName.value = null;
      await loadTemplate();
    }
  }

  Future<void> refreshTemplateNames({bool forceRefresh = true}) async {
    final names = await templateService.fetchTemplateNames(
      forceRefresh: forceRefresh,
    );
    templateOptions.value = names;
  }

  Future<void> selectTemplate(String? templateName) async {
    selectedTemplateName.value =
        (templateName != null && templateName.trim().isNotEmpty)
        ? templateName.trim()
        : null;
    await loadTemplate(templateName: selectedTemplateName.value);
  }

  Future<void> saveCurrentTemplateAs(String rawTemplateName) async {
    final templateName = rawTemplateName.trim();
    if (templateName.isEmpty) return;

    isLoading.value = true;
    try {
      await templateService.saveTemplateAs(
        templateName: templateName,
        displayName: templateName,
        templateData: _templateData,
      );

      await refreshTemplateNames(forceRefresh: true);
      selectedTemplateName.value = templateName;
      await loadTemplate(templateName: templateName);

      Get.snackbar(
        'Success',
        'New template "$templateName" created',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to save template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> saveSelectedTemplate() async {
    final templateName = selectedTemplateName.value;
    if (templateName == null || templateName.trim().isEmpty) {
      Get.snackbar(
        'Info',
        'Default template changes are already applied directly.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    try {
      await templateService.saveTemplate(
        templateName: templateName,
        templateData: _templateData,
        displayName: (_templateData['name'] ?? templateName).toString(),
      );

      await loadTemplate(templateName: templateName);
      Get.snackbar(
        'Success',
        'Template "$templateName" updated',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to save template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteSelectedTemplate() async {
    final templateName = selectedTemplateName.value;
    if (templateName == null || templateName.trim().isEmpty) {
      Get.snackbar(
        'Info',
        'Default template cannot be deleted from this action',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    try {
      await templateService.deleteNamedTemplate(templateName);
      await refreshTemplateNames(forceRefresh: true);

      if (templateOptions.isNotEmpty) {
        final next = (templateOptions.first['templateName'] ?? '').toString();
        selectedTemplateName.value = next.isEmpty ? null : next;
      } else {
        selectedTemplateName.value = null;
      }

      await loadTemplate(templateName: selectedTemplateName.value);
      Get.snackbar(
        'Deleted',
        'Template "$templateName" deleted',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Failed to delete template: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadTemplate({String? templateName}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      // Save current expansion states before reloading
      _saveExpansionStates();

      final templateData = await templateService.fetchTemplate(
        templateName: templateName,
        forceRefresh: true,
      );
      _templateData = templateData;

      final stageKeys =
          templateData.keys
              .where(
                (key) => RegExp(r'^stage[1-9]\d*$').hasMatch(key.toString()),
              )
              .map((e) => e.toString())
              .toList()
            ..sort((a, b) {
              final numA = int.tryParse(a.replaceAll('stage', '')) ?? 0;
              final numB = int.tryParse(b.replaceAll('stage', '')) ?? 0;
              return numA.compareTo(numB);
            });

      final stageNames =
          (templateData['stageNames'] as Map<String, dynamic>?) ??
          (templateData['phaseNames'] as Map<String, dynamic>?) ??
          {};

      final newPhases = <PhaseModel>[];
      for (var stage in stageKeys) {
        final phaseNum = int.tryParse(stage.replaceAll('stage', '')) ?? 0;
        final stageData = templateData[stage] ?? [];
        final displayName = (stageNames[stage] as String?) ?? 'Phase $phaseNum';
        newPhases.add(
          PhaseModel(
            id: 'p$phaseNum',
            name: displayName,
            stage: stage,
            groups: _parseStageData(stageData),
          ),
        );
      }

      final parsedCategories = _parseDefectCategories(
        templateData['defectCategories'] ?? [],
      );

      phases.value = newPhases;
      defectCategories.value = parsedCategories;

      if (defectCategories.isEmpty || defectCategories.length <= 4) {
        defectCategories.value = _getDefaultDefectCategories();
        // Persist defaults to backend
        await templateService.updateDefectCategories(
          defectCategories.toList(),
          templateName: selectedTemplateName.value,
        );
      }

      isLoading.value = false;
    } catch (e) {
      if (e.toString().contains('Template not found')) {
        if (selectedTemplateName.value != null) {
          errorMessage.value =
              'Selected template was not found. Please choose another template.';
          isLoading.value = false;
          return;
        }

        try {
          await templateService.createOrUpdateTemplate();
          await loadTemplate(templateName: selectedTemplateName.value);
        } catch (createError) {
          errorMessage.value = 'Failed to create template: $createError';
          isLoading.value = false;
        }
      } else {
        errorMessage.value = 'Error loading template: $e';
        isLoading.value = false;
      }
    }
  }

  Future<void> updateDefectCategories(List<DefectCategory> updated) async {
    try {
      await templateService.updateDefectCategories(
        updated,
        templateName: selectedTemplateName.value,
      );
      defectCategories.value = updated;
      Get.snackbar(
        'Saved',
        'Defect categories updated',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update categories: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> addPhase(String stageName) async {
    if (stageName.trim().isEmpty) return;
    isLoading.value = true;
    try {
      int nextStageNum = 1;
      _templateData.forEach((key, value) {
        if (RegExp(r'^stage[1-9]\d*$').hasMatch(key.toString())) {
          final numStr = key.toString().replaceAll('stage', '');
          final num = int.tryParse(numStr);
          if (num != null && num >= nextStageNum) {
            nextStageNum = num + 1;
          }
        }
      });
      final newStage = 'stage$nextStageNum';
      await templateService.addStage(
        stage: newStage,
        stageName: stageName,
        templateName: selectedTemplateName.value,
      );
      await loadTemplate(templateName: selectedTemplateName.value);
      Get.snackbar(
        'Success',
        '"$stageName" stage added successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Error adding phase: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deletePhase(PhaseModel phase) async {
    isLoading.value = true;
    try {
      await templateService.deleteStage(
        stage: phase.stage,
        templateName: selectedTemplateName.value,
      );
      await loadTemplate(templateName: selectedTemplateName.value);
      Get.snackbar(
        'Success',
        'Phase "${phase.name}" deleted',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Error deleting phase: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void refreshPhases() => phases.refresh();

  // Save expansion states before reloading
  void _saveExpansionStates() {
    _groupExpansionStates.clear();
    _sectionExpansionStates.clear();

    for (var phase in phases) {
      for (var group in phase.groups) {
        _groupExpansionStates[group.id] = group.expanded;
        for (var section in group.sections) {
          _sectionExpansionStates[section.id] = section.expanded;
        }
      }
    }
  }

  // Parsing helpers
  List<TemplateGroup> _parseStageData(dynamic stageData) {
    if (stageData is! List) {
      if (stageData is Map) {
        stageData = [stageData];
      } else {
        return [];
      }
    }
    return stageData
        .map((checklistData) {
          if (checklistData is! Map<String, dynamic>) return null;
          final id = (checklistData['_id'] ?? '').toString();
          final text = (checklistData['text'] ?? '').toString();
          final checkpointsData = _ensureList(checklistData['checkpoints']);
          final sectionsData = _ensureList(checklistData['sections']);

          final questions = checkpointsData
              .map((cpData) {
                if (cpData is! Map<String, dynamic>) return null;
                return TemplateQuestion(
                  id: (cpData['_id'] ?? '').toString(),
                  text: (cpData['text'] ?? '').toString(),
                );
              })
              .whereType<TemplateQuestion>()
              .toList();

          final sections = sectionsData
              .map((sectionData) {
                if (sectionData is! Map<String, dynamic>) return null;
                final sectionId = (sectionData['_id'] ?? '').toString();
                final sectionText = (sectionData['text'] ?? '').toString();
                final sectionCheckpoints = _ensureList(
                  sectionData['checkpoints'],
                );

                final sectionQuestions = sectionCheckpoints
                    .map((cpData) {
                      if (cpData is! Map<String, dynamic>) return null;
                      return TemplateQuestion(
                        id: (cpData['_id'] ?? '').toString(),
                        text: (cpData['text'] ?? '').toString(),
                      );
                    })
                    .whereType<TemplateQuestion>()
                    .toList();

                return TemplateSection(
                  id: sectionId,
                  name: sectionText,
                  questions: sectionQuestions,
                  expanded: _sectionExpansionStates[sectionId] ?? false,
                );
              })
              .whereType<TemplateSection>()
              .toList();

          return TemplateGroup(
            id: id,
            name: text,
            questions: questions,
            sections: sections,
            expanded: _groupExpansionStates[id] ?? false,
          );
        })
        .whereType<TemplateGroup>()
        .toList();
  }

  List<dynamic> _ensureList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return [data];
    return [];
  }

  List<DefectCategory> _parseDefectCategories(dynamic categoriesData) {
    final list = _ensureList(categoriesData);
    return list
        .map((catData) {
          if (catData is! Map<String, dynamic>) return null;
          return DefectCategory(
            id: (catData['_id'] ?? '').toString(),
            name: (catData['name'] ?? '').toString(),
            keywords:
                (catData['keywords'] as List<dynamic>?)
                    ?.map((k) => k.toString())
                    .toList() ??
                [],
          );
        })
        .whereType<DefectCategory>()
        .toList();
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
