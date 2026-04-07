import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as templateService from "../services/template.service.js";

export const createTemplate = asyncHandler(async (req, res) => {
  const { name } = req.body;
  const { template, created } = await templateService.createOrUpdateTemplate(
    name,
    req.user?._id,
  );
  const status = created ? 201 : 200;
  const message = created
    ? "Template created successfully"
    : "Template updated successfully";
  return res.status(status).json(new ApiResponse(status, template, message));
});

export const getTemplate = asyncHandler(async (req, res) => {
  const { stage } = req.query;
  const data = await templateService.getTemplate(stage);
  const message = stage
    ? `Template ${stage} fetched successfully`
    : "Template fetched successfully";
  return res.status(200).json(new ApiResponse(200, data, message));
});

export const addChecklistToTemplate = asyncHandler(async (req, res) => {
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.addChecklistToTemplate(
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        template,
        "Checklist added to template successfully",
      ),
    );
});

export const updateChecklistInTemplate = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.updateChecklistInTemplate(
    checklistId,
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist updated successfully"));
});

export const deleteChecklistFromTemplate = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");
  const template = await templateService.deleteChecklistFromTemplate(
    checklistId,
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist deleted successfully"));
});

export const addCheckpointToTemplate = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.addCheckpointToTemplate(
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

export const addCheckpointToSection = asyncHandler(async (req, res) => {
  const { checklistId, sectionId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.addCheckpointToSection(
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

export const updateCheckpointInSection = asyncHandler(async (req, res) => {
  const { checklistId, sectionId, checkpointId } = req.params;
  const { stage, text, categoryId } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.updateCheckpointInSection(
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

export const deleteCheckpointFromSection = asyncHandler(async (req, res) => {
  const { checklistId, sectionId, checkpointId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");
  const template = await templateService.deleteCheckpointFromSection(
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

export const updateCheckpointInTemplate = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { stage, checklistId, text, categoryId } = req.body;
  if (!stage || !checklistId || !text)
    throw new ApiError(400, "stage, checklistId, and text are required");
  const template = await templateService.updateCheckpointInTemplate(
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

export const deleteCheckpointFromTemplate = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { stage, checklistId } = req.body;
  if (!stage || !checklistId)
    throw new ApiError(400, "stage and checklistId are required");
  const template = await templateService.deleteCheckpointFromTemplate(
    checkpointId,
    stage,
    checklistId,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint deleted successfully"));
});

export const seedTemplate = asyncHandler(async (req, res) => {
  const { template, alreadyExists } = await templateService.seedTemplate(
    req.user?._id,
  );
  if (alreadyExists) {
    return res
      .status(400)
      .json(
        new ApiResponse(
          400,
          template,
          "Template already exists. Delete it first to seed again.",
        ),
      );
  }
  return res
    .status(201)
    .json(
      new ApiResponse(
        201,
        template,
        "Sample template created successfully. You can now start projects!",
      ),
    );
});

export const updateDefectCategories = asyncHandler(async (req, res) => {
  const { defectCategories, defectCategoryGroups } = req.body;
  if (!defectCategories || !Array.isArray(defectCategories))
    throw new ApiError(400, "defectCategories array is required");
  const template = await templateService.updateDefectCategories(
    defectCategories,
    req.user?._id,
    defectCategoryGroups
  );
  return res
    .status(200)
    .json(
      new ApiResponse(200, template, "Defect categories updated successfully"),
    );
});

export const addSectionToChecklist = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.addSectionToChecklist(
    checklistId,
    stage,
    text,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section added successfully"));
});

export const updateSectionInChecklist = asyncHandler(async (req, res) => {
  const { checklistId, sectionId } = req.params;
  const { stage, text } = req.body;
  if (!stage || !text) throw new ApiError(400, "stage and text are required");
  const template = await templateService.updateSectionInChecklist(
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

export const deleteSectionFromChecklist = asyncHandler(async (req, res) => {
  const { checklistId, sectionId } = req.params;
  const { stage } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");
  const template = await templateService.deleteSectionFromChecklist(
    checklistId,
    sectionId,
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section deleted successfully"));
});

export const addStageToTemplate = asyncHandler(async (req, res) => {
  const { stage, stageName } = req.body;
  if (!stage) throw new ApiError(400, "stage is required");
  const template = await templateService.addStageToTemplate(
    stage,
    stageName,
    req.user?._id,
  );
  return res
    .status(201)
    .json(
      new ApiResponse(
        201,
        template,
        `Stage ${stage} added to template successfully`,
      ),
    );
});

export const deleteStageFromTemplate = asyncHandler(async (req, res) => {
  const { stage } = req.params;
  const template = await templateService.deleteStageFromTemplate(
    stage,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        template,
        `Stage ${stage} deleted from template successfully`,
      ),
    );
});

export const renameStageInTemplate = asyncHandler(async (req, res) => {
  const { stage } = req.params;
  const { stageName } = req.body;
  if (!stageName) throw new ApiError(400, "stageName is required");

  const template = await templateService.renameStageInTemplate(
    stage,
    stageName,
    req.user?._id,
  );
  return res
    .status(200)
    .json(
      new ApiResponse(200, template, `Stage ${stage} renamed successfully`),
    );
});

export const getAllStages = asyncHandler(async (req, res) => {
  const stages = await templateService.getAllStages();
  return res
    .status(200)
    .json(new ApiResponse(200, stages, "All stages retrieved successfully"));
});

export const resetTemplate = asyncHandler(async (req, res) => {
  const result = await templateService.resetTemplate();
  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        result,
        "Template has been reset. Create a new template to continue.",
      ),
    );
});
