import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as templateService from "../services/template.service.multi.js";

// Create a new template
export const createTemplate = asyncHandler(async (req, res) => {
  const { templateName, name, description } = req.body;
  if (!templateName) throw new ApiError(400, "templateName is required");

  const template = await templateService.createTemplate(
    templateName,
    name,
    description,
    req.user?._id,
  );
  return res
    .status(201)
    .json(new ApiResponse(201, template, "Template created successfully"));
});

// Save a full template payload under a new name
export const saveTemplatePayload = asyncHandler(async (req, res) => {
  const { templateName, name, description, templateData } = req.body;
  if (!templateName) throw new ApiError(400, "templateName is required");
  if (!templateData || typeof templateData !== "object") {
    throw new ApiError(400, "templateData is required");
  }

  const template = await templateService.saveTemplatePayload(
    templateName,
    name,
    description,
    templateData,
    req.user?._id,
  );

  return res
    .status(201)
    .json(new ApiResponse(201, template, "Template saved successfully"));
});

// Update an existing template's full payload
export const updateTemplatePayload = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const { name, description, templateData } = req.body;
  if (!templateName) throw new ApiError(400, "templateName is required");
  if (!templateData || typeof templateData !== "object") {
    throw new ApiError(400, "templateData is required");
  }

  const template = await templateService.updateTemplatePayload(
    templateName,
    name,
    description,
    templateData,
    req.user?._id,
  );

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Template updated successfully"));
});

// Get all template names (for dropdowns)
export const getAllTemplateNames = asyncHandler(async (req, res) => {
  const templates = await templateService.getAllTemplateNames(true);
  return res
    .status(200)
    .json(
      new ApiResponse(200, templates, "Templates list fetched successfully"),
    );
});

// Get a single template by name
export const getTemplate = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const { stage } = req.query;
  const data = await templateService.getTemplate(templateName, stage);
  return res
    .status(200)
    .json(new ApiResponse(200, data, "Template fetched successfully"));
});

// Update template metadata
export const updateTemplate = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const template = await templateService.updateTemplateMetadata(
    templateName,
    req.body,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Template updated successfully"));
});

// Delete a template
export const deleteTemplate = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const result = await templateService.deleteTemplate(templateName);
  return res
    .status(200)
    .json(new ApiResponse(200, result, "Template deleted successfully"));
});

// Duplicate a template under a new name
export const duplicateTemplate = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const { newTemplateName } = req.body;
  if (!newTemplateName) throw new ApiError(400, "newTemplateName is required");

  const template = await templateService.duplicateTemplate(
    templateName,
    newTemplateName,
    req.user?._id,
  );
  return res
    .status(201)
    .json(new ApiResponse(201, template, "Template duplicated successfully"));
});

// Checklist group management

// Add a checklist group to a template stage
export const addChecklistToTemplate = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.addChecklistToTemplate(
    templateName,
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist added successfully"));
});

// Update a checklist group
export const updateChecklistInTemplate = asyncHandler(async (req, res) => {
  const { templateName, checklistId } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.updateChecklistInTemplate(
    templateName,
    checklistId,
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist updated successfully"));
});

// Delete a checklist group
export const deleteChecklistFromTemplate = asyncHandler(async (req, res) => {
  const { templateName, checklistId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");

  const template = await templateService.deleteChecklistFromTemplate(
    templateName,
    checklistId,
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist deleted successfully"));
});

// Checkpoint (Question) management

// Add a checkpoint to a checklist group
export const addCheckpointToTemplate = asyncHandler(async (req, res) => {
  const { templateName, checklistId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.addCheckpointToTemplate(
    templateName,
    checklistId,
    stage,
    text,
    categoryId,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint added successfully"));
});

// Update a checkpoint in a checklist group
export const updateCheckpointInTemplate = asyncHandler(async (req, res) => {
  const { templateName, checklistId, checkpointId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.updateCheckpointInTemplate(
    templateName,
    checkpointId,
    stage,
    checklistId,
    text,
    categoryId,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint updated successfully"));
});

// Delete a checkpoint from a checklist group
export const deleteCheckpointFromTemplate = asyncHandler(async (req, res) => {
  const { templateName, checklistId, checkpointId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");

  const template = await templateService.deleteCheckpointFromTemplate(
    templateName,
    checkpointId,
    stage,
    checklistId,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint deleted successfully"));
});

// Section management

// Add a section to a checklist group
export const addSectionToChecklist = asyncHandler(async (req, res) => {
  const { templateName, checklistId } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.addSectionToChecklist(
    templateName,
    checklistId,
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section added successfully"));
});

// Update a section
export const updateSectionInChecklist = asyncHandler(async (req, res) => {
  const { templateName, checklistId, sectionId } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.updateSectionInChecklist(
    templateName,
    checklistId,
    sectionId,
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section updated successfully"));
});

// Delete a section
export const deleteSectionFromChecklist = asyncHandler(async (req, res) => {
  const { templateName, checklistId, sectionId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");

  const template = await templateService.deleteSectionFromChecklist(
    templateName,
    checklistId,
    sectionId,
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section deleted successfully"));
});

// Checkpoint management on sections

// Add a checkpoint to a section
export const addCheckpointToSection = asyncHandler(async (req, res) => {
  const { templateName, checklistId, sectionId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.addCheckpointToSection(
    templateName,
    checklistId,
    sectionId,
    stage,
    text,
    categoryId,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        template,
        "Checkpoint added to section successfully",
      ),
    );
});

// Update a checkpoint in a section
export const updateCheckpointInSection = asyncHandler(async (req, res) => {
  const { templateName, checklistId, sectionId, checkpointId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");

  const template = await templateService.updateCheckpointInSection(
    templateName,
    checklistId,
    sectionId,
    checkpointId,
    stage,
    text,
    categoryId,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        template,
        "Checkpoint updated in section successfully",
      ),
    );
});

// Delete a checkpoint from a section
export const deleteCheckpointFromSection = asyncHandler(async (req, res) => {
  const { templateName, checklistId, sectionId, checkpointId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");

  const template = await templateService.deleteCheckpointFromSection(
    templateName,
    checklistId,
    sectionId,
    checkpointId,
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        template,
        "Checkpoint deleted from section successfully",
      ),
    );
});

// Stage management

// Add a stage to a template
export const addStageToTemplate = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const { stage, stageName } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");

  const template = await templateService.addStageToTemplate(
    templateName,
    stage,
    stageName,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Stage added successfully"));
});

// Delete a stage from a template
export const deleteStageFromTemplate = asyncHandler(async (req, res) => {
  const { templateName, stage } = req.params;

  const template = await templateService.deleteStageFromTemplate(
    templateName,
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Stage deleted successfully"));
});

// Get all stages in a template
export const getAllStages = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const stages = await templateService.getAllStages(templateName);
  return res
    .status(200)
    .json(new ApiResponse(200, stages, "Stages fetched successfully"));
});

// Defect categories

// Update defect categories for a template
export const updateDefectCategories = asyncHandler(async (req, res) => {
  const { templateName } = req.params;
  const { defectCategories } = req.body;
  if (!Array.isArray(defectCategories))
    throw new ApiError(400, "defectCategories must be an array");

  const template = await templateService.updateDefectCategories(
    templateName,
    defectCategories,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(200, template, "Defect categories updated successfully"),
    );
});

// Seed

// Create sample templates for testing
export const seedSampleTemplates = asyncHandler(async (req, res) => {
  const result = await templateService.seedSampleTemplates(req.user?._id);
  return res
    .status(201)
    .json(
      new ApiResponse(201, result, "Sample templates created successfully"),
    );
});
