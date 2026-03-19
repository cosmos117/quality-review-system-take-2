import 'package:get/get.dart';
import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import 'api_cache.dart';
import 'http_client.dart';

/// Service for Template Management API operations
/// Handles admin template CRUD operations with backend integration
class TemplateService {
  final SimpleHttp http;
  final ApiCache _cache = ApiCache(defaultTtl: const Duration(minutes: 5));

  TemplateService(this.http);

  static const String _baseUrl = '${ApiConfig.baseUrl}/templates';
  static const String _libraryBaseUrl = '${ApiConfig.baseUrl}/template-library';

  /// Ensure token is set from current user
  void _ensureToken() {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      if (auth.currentUser.value != null &&
          auth.currentUser.value!.token.isNotEmpty) {
        http.accessToken = auth.currentUser.value!.token;
      }
    }
  }

  String _templateRoot(String? templateName) {
    if (templateName != null && templateName.trim().isNotEmpty) {
      final encoded = Uri.encodeComponent(templateName.trim());
      return '$_libraryBaseUrl/$encoded';
    }
    return _baseUrl;
  }

  Future<void> deleteNamedTemplate(String templateName) async {
    try {
      _ensureToken();
      final root = _templateRoot(templateName);
      await http.delete(Uri.parse(root));
      _cache.clear();
    } catch (e) {
      throw Exception('Error deleting template: $e');
    }
  }

  Future<Map<String, dynamic>> updateNamedTemplateMetadata({
    required String templateName,
    String? name,
    String? description,
    bool? isActive,
    Map<String, dynamic>? stageNames,
  }) async {
    try {
      _ensureToken();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (isActive != null) body['isActive'] = isActive;
      if (stageNames != null) body['stageNames'] = stageNames;

      final root = _templateRoot(templateName);
      final response = await http.patchJson(Uri.parse(root), body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating template metadata: $e');
    }
  }

  Future<Map<String, dynamic>> renameStage({
    required String stage,
    required String stageName,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }
      if (stageName.trim().isEmpty) {
        throw Exception('Stage name is required');
      }

      if (templateName != null && templateName.trim().isNotEmpty) {
        final current = await fetchTemplate(templateName: templateName);
        final currentStageNames =
            (current['stageNames'] as Map<String, dynamic>?) ?? {};
        final merged = {...currentStageNames, stage: stageName.trim()};
        return updateNamedTemplateMetadata(
          templateName: templateName,
          stageNames: merged,
        );
      }

      final response = await http.patchJson(
        Uri.parse('$_baseUrl/stages/$stage/name'),
        {'stageName': stageName.trim()},
      );
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error renaming stage: $e');
    }
  }

  /// Get all saved template names for dropdown.
  Future<List<Map<String, dynamic>>> fetchTemplateNames({
    bool forceRefresh = false,
  }) async {
    return _cache.get('template:names', () async {
      try {
        _ensureToken();
        final response = await http.getJson(Uri.parse('$_libraryBaseUrl/list'));
        final data = response['data'];
        if (data is List) {
          return data.map((e) {
            if (e is Map<String, dynamic>) return e;
            return <String, dynamic>{};
          }).toList();
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        throw Exception('Error fetching template names: $e');
      }
    }, forceRefresh: forceRefresh);
  }

  /// Save a complete template payload as a new named template.
  Future<Map<String, dynamic>> saveTemplateAs({
    required String templateName,
    required Map<String, dynamic> templateData,
    String? displayName,
    String? description,
  }) async {
    try {
      _ensureToken();
      final body = <String, dynamic>{
        'templateName': templateName,
        'templateData': templateData,
      };
      if (displayName != null && displayName.trim().isNotEmpty) {
        body['name'] = displayName.trim();
      }
      if (description != null) {
        body['description'] = description;
      }

      final response = await http.postJson(
        Uri.parse('$_libraryBaseUrl/save'),
        body,
      );
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error saving template: $e');
    }
  }

  /// Save/update a complete payload into an existing named template.
  Future<Map<String, dynamic>> saveTemplate({
    required String templateName,
    required Map<String, dynamic> templateData,
    String? displayName,
    String? description,
  }) async {
    try {
      _ensureToken();
      final body = <String, dynamic>{'templateData': templateData};
      if (displayName != null && displayName.trim().isNotEmpty) {
        body['name'] = displayName.trim();
      }
      if (description != null) {
        body['description'] = description;
      }

      final root = _templateRoot(templateName);
      final response = await http.putJson(Uri.parse('$root/save'), body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating template: $e');
    }
  }

  /// Fetch the complete template with all stages
  /// Optional [stage] parameter to filter by specific stage (stage1, stage2, stage3, stage4, etc.)
  Future<Map<String, dynamic>> fetchTemplate({
    String? stage,
    String? templateName,
    bool forceRefresh = false,
  }) async {
    final root = _templateRoot(templateName);
    final cacheKeyBase = templateName != null
        ? 'template:named:$templateName'
        : 'template:legacy';
    final cacheKey = stage != null
        ? '$cacheKeyBase:$stage'
        : '$cacheKeyBase:full';

    return _cache.get(cacheKey, () async {
      try {
        _ensureToken();
        String urlString = root;
        if (stage != null && _isValidStage(stage)) {
          urlString = '$urlString?stage=$stage';
        }

        final response = await http.getJson(Uri.parse(urlString));
        // API responses are wrapped in { statusCode, data, message }
        // Return only the payload to callers
        return response['data'] as Map<String, dynamic>? ?? response;
      } catch (e) {
        throw Exception('Error fetching template: $e');
      }
    }, forceRefresh: forceRefresh);
  }

  /// Validate if stage name is in correct format (stage1, stage2, stage3, stage4, etc.)
  bool _isValidStage(String stage) {
    // Match stage1, stage2, stage3, ..., stage99
    return RegExp(r'^stage[1-9]\d*$').hasMatch(stage);
  }

  /// Create or update the template
  /// Uses POST to create initial template or update existing template name
  Future<Map<String, dynamic>> createOrUpdateTemplate({String? name}) async {
    try {
      _ensureToken();
      final body = <String, dynamic>{};
      if (name != null) {
        body['name'] = name;
      }

      final response = await http.postJson(Uri.parse(_baseUrl), body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error creating/updating template: $e');
    }
  }

  /// Add a checklist to a specific stage
  /// [stage] must be in format: stage1, stage2, stage3, stage4, etc.
  /// [checklistName] is the checklist group name
  Future<Map<String, dynamic>> addChecklist({
    required String stage,
    required String checklistName,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception(
          'Invalid stage format. Must be stage1, stage2, stage3, etc.',
        );
      }

      final root = _templateRoot(templateName);
      final response = await http.postJson(Uri.parse('$root/checklists'), {
        'stage': stage,
        'text': checklistName,
      });
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding checklist: $e');
    }
  }

  /// Update a checklist's name
  /// [checklistId] is the MongoDB _id of the checklist
  /// [stage] indicates which stage the checklist belongs to
  /// [newName] is the updated checklist name
  Future<Map<String, dynamic>> updateChecklist({
    required String checklistId,
    required String stage,
    required String newName,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      final response = await http.patchJson(
        Uri.parse('$root/checklists/$checklistId'),
        {'stage': stage, 'text': newName},
      );
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating checklist: $e');
    }
  }

  /// Delete a checklist from the template
  /// [checklistId] is the MongoDB _id of the checklist
  /// [stage] indicates which stage the checklist belongs to
  Future<void> deleteChecklist({
    required String checklistId,
    required String stage,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      await http.deleteJson(Uri.parse('$root/checklists/$checklistId'), {
        'stage': stage,
      });
      _cache.clear();
    } catch (e) {
      throw Exception('Error deleting checklist: $e');
    }
  }

  /// Add a checkpoint (question) to a checklist
  /// [checklistId] is the MongoDB _id of the checklist
  /// [stage] indicates which stage the checklist belongs to
  /// [questionText] is the checkpoint text
  /// [categoryId] optional defect category ID
  /// [sectionId] optional - if provided, adds to section; otherwise adds to group directly
  Future<Map<String, dynamic>> addCheckpoint({
    required String checklistId,
    required String stage,
    required String questionText,
    String? categoryId,
    String? sectionId,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      // Build endpoint based on whether sectionId is provided
      final String endpoint = sectionId != null
          ? '$root/checklists/$checklistId/sections/$sectionId/checkpoints'
          : '$root/checklists/$checklistId/checkpoints';

      final body = {
        'stage': stage,
        'text': questionText,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
      };

      final response = await http.postJson(Uri.parse(endpoint), body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding checkpoint: $e');
    }
  }

  /// Update a checkpoint (question) text
  /// [checkpointId] is the MongoDB _id of the checkpoint
  /// [checklistId] is the MongoDB _id of the parent checklist
  /// [stage] indicates which stage the checkpoint belongs to
  /// [newText] is the updated checkpoint text
  /// [categoryId] optional defect category ID
  Future<Map<String, dynamic>> updateCheckpoint({
    required String checkpointId,
    required String checklistId,
    required String stage,
    required String newText,
    String? categoryId,
    String? sectionId,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      // Choose endpoint based on section presence
      final String endpoint = sectionId != null
          ? '$root/checklists/$checklistId/sections/$sectionId/checkpoints/$checkpointId'
          : (templateName != null
                ? '$root/checklists/$checklistId/checkpoints/$checkpointId'
                : '$_baseUrl/checkpoints/$checkpointId');

      final body = {
        'checklistId': checklistId,
        'stage': stage,
        'text': newText,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
      };

      final response = await http.patchJson(Uri.parse(endpoint), body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating checkpoint: $e');
    }
  }

  /// Delete a checkpoint (question) from a checklist or section
  /// [checkpointId] is the MongoDB _id of the checkpoint
  /// [checklistId] is the MongoDB _id of the parent checklist
  /// [stage] indicates which stage the checkpoint belongs to
  /// [sectionId] optional - if provided, deletes from section; otherwise deletes from group directly
  Future<Map<String, dynamic>> deleteCheckpoint({
    required String checkpointId,
    required String checklistId,
    required String stage,
    String? sectionId,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      // Build endpoint based on whether sectionId is provided
      final String endpoint = sectionId != null
          ? '$root/checklists/$checklistId/sections/$sectionId/checkpoints/$checkpointId'
          : (templateName != null
                ? '$root/checklists/$checklistId/checkpoints/$checkpointId'
                : '$_baseUrl/checkpoints/$checkpointId');

      final response = await http.deleteJson(Uri.parse(endpoint), {
        'checklistId': checklistId,
        'stage': stage,
      });
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error deleting checkpoint: $e');
    }
  }

  /// Update defect categories in template
  Future<void> updateDefectCategories(
    List<dynamic> categories, {
    String? templateName,
  }) async {
    try {
      _ensureToken();

      final body = {
        'defectCategories': categories.map((c) => c.toJson()).toList(),
      };

      if (templateName != null && templateName.trim().isNotEmpty) {
        final root = _templateRoot(templateName);
        await http.putJson(Uri.parse('$root/categories'), body);
      } else {
        await http.patchJson(Uri.parse('$_baseUrl/defect-categories'), body);
      }

      _cache.clear();
    } catch (e) {
      throw Exception('Error updating defect categories: $e');
    }
  }

  /// Add a section to a checklist group in the template
  /// [checklistId] is the MongoDB _id of the checklist (group)
  /// [stage] indicates which stage the checklist belongs to
  /// [sectionName] is the name of the new section
  Future<Map<String, dynamic>> addSection({
    required String checklistId,
    required String stage,
    required String sectionName,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      final response = await http.postJson(
        Uri.parse('$root/checklists/$checklistId/sections'),
        {'stage': stage, 'text': sectionName},
      );
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding section: $e');
    }
  }

  /// Update a section in a checklist group in the template
  /// [checklistId] is the MongoDB _id of the checklist (group)
  /// [sectionId] is the MongoDB _id of the section
  /// [stage] indicates which stage the checklist belongs to
  /// [newName] is the updated section name
  Future<Map<String, dynamic>> updateSection({
    required String checklistId,
    required String sectionId,
    required String stage,
    required String newName,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      final uri = Uri.parse(
        '$root/checklists/$checklistId/sections/$sectionId',
      );
      final body = {'stage': stage, 'text': newName};
      final response = templateName != null
          ? await http.patchJson(uri, body)
          : await http.putJson(uri, body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error updating section: $e');
    }
  }

  /// Delete a section from a checklist group in the template
  /// [checklistId] is the MongoDB _id of the checklist (group)
  /// [sectionId] is the MongoDB _id of the section
  /// [stage] indicates which stage the checklist belongs to
  Future<void> deleteSection({
    required String checklistId,
    required String sectionId,
    required String stage,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception('Invalid stage format');
      }

      final root = _templateRoot(templateName);
      await http.deleteJson(
        Uri.parse('$root/checklists/$checklistId/sections/$sectionId'),
        {'stage': stage},
      );
      _cache.clear();
    } catch (e) {
      throw Exception('Error deleting section: $e');
    }
  }

  /// Add a new stage to the template
  /// [stage] must be in format: stage1, stage2, stage3, stage4, etc.
  /// Add a new stage to the template with optional custom name
  /// [stage] must be in format: stage1, stage2, stage3, etc.
  /// [stageName] is optional custom display name for the stage
  Future<Map<String, dynamic>> addStage({
    required String stage,
    String? stageName,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception(
          'Invalid stage format. Must be stage1, stage2, stage3, etc.',
        );
      }

      final root = _templateRoot(templateName);
      final body = {'stage': stage};
      if (stageName != null && stageName.trim().isNotEmpty) {
        body['stageName'] = stageName.trim();
      }

      final response = await http.postJson(Uri.parse('$root/stages'), body);
      _cache.clear();
      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      throw Exception('Error adding stage: $e');
    }
  }

  /// Delete a stage from the template
  /// [stage] must be in format: stage1, stage2, stage3, stage4, etc.
  Future<void> deleteStage({
    required String stage,
    String? templateName,
  }) async {
    try {
      _ensureToken();
      if (!_isValidStage(stage)) {
        throw Exception(
          'Invalid stage format. Must be stage1, stage2, stage3, etc.',
        );
      }

      final root = _templateRoot(templateName);
      await http.deleteJson(Uri.parse('$root/stages/$stage'), {});
      _cache.clear();
    } catch (e) {
      throw Exception('Error deleting stage: $e');
    }
  }

  /// Get all stages with their names from the template
  Future<Map<String, String>> getStages({
    String? templateName,
    bool forceRefresh = false,
  }) async {
    final cacheKey = templateName != null
        ? 'template:named:$templateName:stages'
        : 'template:stages';

    return _cache.get(cacheKey, () async {
      try {
        _ensureToken();
        final root = _templateRoot(templateName);
        final response = await http.getJson(Uri.parse('$root/stages'));
        final stagesData = response['data'] as Map<String, dynamic>? ?? {};

        return stagesData.map((key, value) {
          return MapEntry(key.toString(), value.toString());
        });
      } catch (e) {
        throw Exception('Error fetching stages: $e');
      }
    }, forceRefresh: forceRefresh);
  }

  void clearCache() => _cache.clear();

  /// Validate template completeness
  /// Returns a map with 'isComplete' boolean and 'incompletePhases' list
  /// Each phase should have at least one checklist with at least one question
  Future<Map<String, dynamic>> validateTemplateCompleteness({
    String? templateName,
  }) async {
    try {
      _ensureToken();
      final template = await fetchTemplate(templateName: templateName);
      final incompletePhases = <String>[];

      // Support both keys for backward compatibility
      final phaseNames =
          template['stageNames'] as Map<String, dynamic>? ??
          template['phaseNames'] as Map<String, dynamic>? ??
          {};

      // Get all stage keys (stage1, stage2, etc.)
      final stageKeys =
          template.keys.where((key) => _isValidStage(key)).toList()
            ..sort((a, b) {
              final numA = int.tryParse(a.replaceAll('stage', '')) ?? 0;
              final numB = int.tryParse(b.replaceAll('stage', '')) ?? 0;
              return numA.compareTo(numB);
            });

      for (final stageKey in stageKeys) {
        final phaseName = phaseNames[stageKey] ?? stageKey;
        final checklists = template[stageKey] as List? ?? [];

        // Check if phase has checklists with questions
        bool hasQuestions = false;

        for (final checklist in checklists) {
          if (checklist is Map<String, dynamic>) {
            final checkpoints = checklist['checkpoints'] as List? ?? [];
            final sections = checklist['sections'] as List? ?? [];

            // Check if there are direct checkpoints
            if (checkpoints.isNotEmpty) {
              hasQuestions = true;
              break;
            }

            // Check if there are checkpoints in sections
            for (final section in sections) {
              if (section is Map<String, dynamic>) {
                final sectionCheckpoints =
                    section['checkpoints'] as List? ?? [];
                if (sectionCheckpoints.isNotEmpty) {
                  hasQuestions = true;
                  break;
                }
              }
            }

            if (hasQuestions) break;
          }
        }

        if (!hasQuestions) {
          incompletePhases.add(phaseName);
        }
      }

      return {
        'isComplete': incompletePhases.isEmpty,
        'incompletePhases': incompletePhases,
      };
    } catch (e) {
      throw Exception('Error validating template: $e');
    }
  }
}
