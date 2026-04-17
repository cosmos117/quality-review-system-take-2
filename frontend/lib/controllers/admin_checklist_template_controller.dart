import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/template_models.dart';
import '../services/template_service.dart';

class AdminChecklistTemplateController extends GetxController {
  final TemplateService templateService = Get.find<TemplateService>();

  final phases = <PhaseModel>[].obs;
  final defectCategories = <DefectCategory>[].obs;
  final defectCategoryGroups = <String>[].obs;
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

  // Recursion guard for error handling
  bool _isReloading = false;

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

      // Load defect categories and groups GLOBALLY instead of from the template
      final defectSettings = await templateService.fetchGlobalDefectCategories(
        forceRefresh: true,
      );

      final parsedCategories = _parseDefectCategories(
        defectSettings['categories'] ?? [],
      );

      phases.value = newPhases;
      defectCategories.value = parsedCategories;
      defectCategoryGroups.value = _ensureList(
        defectSettings['groups'],
      ).map((e) => e.toString()).toList();

      if (defectCategories.isEmpty || defectCategories.length <= 4) {
        // ... (preserving logic but potentially updating it to be global)
        // Actually, seed logic is now in the backend, but we'll keep it as a fallback
        if (defectCategories.isEmpty) {
          defectCategories.value = _getDefaultDefectCategories();
          await templateService.updateDefectCategories(
            defectCategories.toList(),
            categoryGroups: defectCategoryGroups.toList(),
          );
        }
      }

      isLoading.value = false;
      _isReloading = false; // Reset on success
    } catch (e) {
      if (e.toString().contains('Template not found')) {
        if (selectedTemplateName.value != null) {
          errorMessage.value =
              'Selected template was not found. Please choose another template.';
          isLoading.value = false;
          return;
        }

        // Recursion guard: Only attempt one auto-create/load retry
        if (_isReloading) {
          errorMessage.value = 'Failed to create and load template: $e';
          isLoading.value = false;
          _isReloading = false;
          return;
        }

        try {
          _isReloading = true;
          await templateService.createOrUpdateTemplate();
          await loadTemplate(templateName: selectedTemplateName.value);
        } catch (createError) {
          errorMessage.value = 'Failed to create template: $createError';
          isLoading.value = false;
          _isReloading = false;
        }
      } else {
        errorMessage.value = 'Error loading template: $e';
        isLoading.value = false;
        _isReloading = false;
      }
    }
  }

  Future<void> updateDefectCategories(
    List<DefectCategory> updated, {
    List<String>? groups,
  }) async {
    try {
      await templateService.updateDefectCategories(
        updated,
        categoryGroups: groups ?? defectCategoryGroups.toList(),
      );
      defectCategories.value = updated;
      if (groups != null) defectCategoryGroups.value = groups;
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
          final id = (checklistData['_id'] ?? checklistData['id'] ?? '')
              .toString();
          final text = (checklistData['text'] ?? '').toString();
          final checkpointsData = _ensureList(checklistData['checkpoints']);
          final sectionsData = _ensureList(checklistData['sections']);

          final questions = checkpointsData
              .map((cpData) {
                if (cpData is! Map<String, dynamic>) return null;
                return TemplateQuestion(
                  id: (cpData['_id'] ?? cpData['id'] ?? '').toString(),
                  text: (cpData['text'] ?? '').toString(),
                );
              })
              .whereType<TemplateQuestion>()
              .toList();

          final sections = sectionsData
              .map((sectionData) {
                if (sectionData is! Map<String, dynamic>) return null;
                final sectionId =
                    (sectionData['_id'] ?? sectionData['id'] ?? '').toString();
                final sectionText = (sectionData['text'] ?? '').toString();
                final sectionCheckpoints = _ensureList(
                  sectionData['checkpoints'],
                );

                final sectionQuestions = sectionCheckpoints
                    .map((cpData) {
                      if (cpData is! Map<String, dynamic>) return null;
                      return TemplateQuestion(
                        id: (cpData['_id'] ?? cpData['id'] ?? '').toString(),
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

  String _normalizeCategoryName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  List<DefectCategory> _parseDefectCategories(dynamic categoriesData) {
    final list = _ensureList(categoriesData);
    final seenNames = <String>{};

    return list
        .map((catData) {
          if (catData is! Map<String, dynamic>) return null;

          // Try multiple ID fields, fallback to a unique local ID if all missing
          String parsedId = (catData['id'] ?? catData['_id'] ?? '').toString();
          if (parsedId.isEmpty) {
            parsedId =
                'temp_cat_${DateTime.now().microsecondsSinceEpoch}_${list.indexOf(catData)}';
          }

          final cleanedName = (catData['name'] ?? '')
              .toString()
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ');
          final cleanedGroup = (catData['group'] ?? 'General')
              .toString()
              .trim();

          return DefectCategory(
            id: parsedId,
            name: cleanedName,
            group: cleanedGroup.isEmpty ? 'General' : cleanedGroup,
            keywords:
                (catData['keywords'] as List<dynamic>?)
                    ?.map((k) => k.toString())
                    .toList() ??
                [],
          );
        })
        .whereType<DefectCategory>()
        .where((cat) {
          final normalizedName = _normalizeCategoryName(cat.name);
          if (normalizedName.isEmpty || seenNames.contains(normalizedName)) {
            return false;
          }

          seenNames.add(normalizedName);
          return true;
        })
        .toList();
  }
}

/// Auto-generates keywords from a category name by splitting on spaces,
/// hyphens and slashes, lowercasing, deduplicating, and filtering short tokens.
List<String> _autoKeywords(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[-/\\]'), ' ')
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.length > 1)
      .toSet()
      .toList();
}

List<DefectCategory> _getDefaultDefectCategories() {
  final names = [
    'Incorrect Modelling Strategy - Geometry',
    'Incorrect Modelling Strategy - Material',
    'Incorrect Modelling Strategy - Loads',
    'Incorrect Modelling Strategy - BC',
    'Incorrect Modelling Strategy - Assumptions',
    'Incorrect Modelling Strategy - Acceptance Criteria',
    'Incorrect geometry units',
    'Incorrect meshing',
    'Defective mesh quality',
    'Incorrect contact definition',
    'Incorrect beam/bolt modeling',
    'RBE/RBE3 are not modeled properly',
    'Incorrect loads and Boundary Condition',
    'Incorrect connectivity',
    'Incorrect degree of element order',
    'Incorrect element quality',
    'Incorrect bolt size',
    'Incorrect elements order',
    'Incorrect elements quality',
    'Incorrect end loads',
    'Too refined mesh at the non critical regions',
    'Support Gap',
    'Support Location',
    'Incorrect Scope',
    'free pages',
    'Incorrect mass modeling',
    'Incorrect material properties',
    'Incorrect global output request',
    'Incorrect loadstep creation',
    'Incorrect output request',
    'Incorrect Interpretation',
    'Incorrect Results location and Values',
    'Incorrect Observation',
    'Incorrect Naming',
    'Missing Results Plot',
    'Incomplete conclusion, suggestions',
    'Template not followed',
    'Checklist not followed',
    'Planning sheet not followed',
    'Folder Structure not followed',
    'Name/revision report incorrect',
    'Typo Textual Error',
  ];
  return names.asMap().entries.map((entry) {
    final i = entry.key + 1;
    final name = entry.value;

    String groupName = 'General';
    if (name.startsWith('Incorrect Modelling Strategy')) {
      groupName = 'Modelling Strategy';
    } else if (name.toLowerCase().contains('results') ||
        name.toLowerCase().contains('output')) {
      groupName = 'Results & Output';
    } else if (name.toLowerCase().contains('mesh')) {
      groupName = 'Meshing';
    }

    return DefectCategory(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}_$i',
      name: name,
      group: groupName,
      keywords: _autoKeywords(name),
    );
  }).toList();
}
