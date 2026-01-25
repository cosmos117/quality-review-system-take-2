import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Template from "../models/template.models.js";

/**
 * Helper function to validate stage format
 * Accepts stage1, stage2, stage3, ... stage99
 */
const isValidStage = (stage) => {
  return /^stage\d{1,2}$/.test(stage);
};

/**
 * CREATE OR UPDATE TEMPLATE
 * POST /api/v1/templates
 * Creates initial template or updates existing template metadata
 * Enforces singleton pattern - only ONE template exists in the system
 */
export const createTemplate = asyncHandler(async (req, res) => {
  const { name } = req.body;

  // Check if template already exists
  let template = await Template.findOne();

  if (template) {
    // Update existing template's name if provided
    if (name) {
      template.name = name;
    }
    template.modifiedBy = req.user?._id;
    await template.save();

    return res
      .status(200)
      .json(new ApiResponse(200, template, "Template updated successfully"));
  }

  // Create new template if none exists
  template = await Template.create({
    name: name || "Default Quality Review Template",
    modifiedBy: req.user?._id,
  });

  return res
    .status(201)
    .json(new ApiResponse(201, template, "Template created successfully"));
});

/**
 * GET TEMPLATE
 * GET /api/v1/templates
 * GET /api/v1/templates?stage=stage1
 * Fetches the single template document (optionally filtered by stage)
 */
export const getTemplate = asyncHandler(async (req, res) => {
  const { stage } = req.query;

  const template = await Template.findOne();

  if (!template) {
    throw new ApiError(404, "Template not found. Please create one first.");
  }

  // If stage filter requested, return only that stage's data
  if (stage) {
    if (!isValidStage(stage)) {
      throw new ApiError(400, "Invalid stage format. Must be stage1-99");
    }
    const filteredData = {
      _id: template._id,
      name: template.name,
      [stage]: template[stage],
      modifiedBy: template.modifiedBy,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    };

    return res
      .status(200)
      .json(
        new ApiResponse(
          200,
          filteredData,
          `Template ${stage} fetched successfully`,
        ),
      );
  }

  // Return full template
  return res
    .status(200)
    .json(new ApiResponse(200, template, "Template fetched successfully"));
});

/**
 * ADD CHECKLIST TO TEMPLATE
 * POST /api/v1/templates/checklists
 * Adds a new checklist group to a specific stage
 * Body: { stage: "stage1" | "stage2" | "stage3", text: "Checklist Name" }
 */
export const addChecklistToTemplate = asyncHandler(async (req, res) => {
  const { stage, text } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Initialize dynamic stage array if it doesn't exist yet
  if (!Array.isArray(template[stage])) {
    template[stage] = [];
  }

  // Add new checklist with empty checkpoints array
  template[stage].push({ text: text.trim(), checkpoints: [] });
  // Ensure Mongoose tracks dynamic stage field
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

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

/**
 * UPDATE CHECKLIST IN TEMPLATE
 * PATCH /api/v1/templates/checklists/:checklistId
 * Updates the text of a checklist within the template
 * Body: { stage: "stage1" | "stage2" | "stage3", text: "New Name" }
 */
export const updateChecklistInTemplate = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage, text } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find checklist in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found in specified stage");
  }

  checklist.text = text.trim();
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist updated successfully"));
});

/**
 * DELETE CHECKLIST FROM TEMPLATE
 * DELETE /api/v1/templates/checklists/:checklistId
 * Removes a checklist from the template
 * Body: { stage: "stage1" | "stage2" | "stage3" }
 */
export const deleteChecklistFromTemplate = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage } = req.body;

  if (!stage) {
    throw new ApiError(400, "stage is required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Filter out the checklist with matching ID
  template[stage] = template[stage].filter(
    (item) => item._id.toString() !== checklistId,
  );

  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checklist deleted successfully"));
});

/**
 * ADD CHECKPOINT TO CHECKLIST IN TEMPLATE
 * POST /api/v1/templates/checklists/:checklistId/checkpoints
 * Adds a checkpoint (question) to a checklist within the template (direct to group)
 * Body: { stage: "stage1" | "stage2" | "stage3", text: "Question text" }
 */
export const addCheckpointToTemplate = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage, text, categoryId } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find checklist in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found in specified stage");
  }

  // Add checkpoint to the checklist
  const checkpointData = { text: text.trim() };
  if (categoryId) {
    checkpointData.categoryId = categoryId;
  }
  checklist.checkpoints.push(checkpointData);
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint added successfully"));
});

/**
 * ADD CHECKPOINT TO SECTION IN TEMPLATE
 * POST /api/v1/templates/checklists/:checklistId/sections/:sectionId/checkpoints
 * Adds a checkpoint (question) to a section within a checklist
 * Body: { stage: "stage1" | "stage2" | "stage3", text: "Question text" }
 */
export const addCheckpointToSection = asyncHandler(async (req, res) => {
  const { checklistId, sectionId } = req.params;
  const { stage, text, categoryId } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find checklist in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found in specified stage");
  }

  // Find section in checklist
  const section = checklist.sections?.find(
    (item) => item._id.toString() === sectionId,
  );

  if (!section) {
    throw new ApiError(404, "Section not found in this checklist");
  }

  // Add checkpoint to the section
  const checkpointData = { text: text.trim() };
  if (categoryId) {
    checkpointData.categoryId = categoryId;
  }
  section.checkpoints.push(checkpointData);
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

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

/**
 * UPDATE CHECKPOINT IN A SECTION
 * PATCH /api/v1/templates/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId
 * Body: { stage: "stage1" | "stage2" | "stage3", text: string, categoryId?: string }
 */
export const updateCheckpointInSection = asyncHandler(async (req, res) => {
  const { checklistId, sectionId, checkpointId } = req.params;
  const { stage, text, categoryId } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found in specified stage");
  }

  const section = checklist.sections?.find(
    (item) => item._id.toString() === sectionId,
  );

  if (!section) {
    throw new ApiError(404, "Section not found in this checklist");
  }

  const checkpoint = section.checkpoints.find(
    (item) => item._id.toString() === checkpointId,
  );

  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found in this section");
  }

  checkpoint.text = text.trim();
  if (categoryId !== undefined) {
    checkpoint.categoryId = categoryId;
  }

  template.markModified(stage);

  template.modifiedBy = req.user?._id;
  await template.save();

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

/**
 * DELETE CHECKPOINT FROM SECTION IN TEMPLATE
 * DELETE /api/v1/templates/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId
 * Removes a checkpoint from a section within a checklist group
 * Body: { stage: "stage1" | "stage2" | "stage3" }
 */
export const deleteCheckpointFromSection = asyncHandler(async (req, res) => {
  const { checklistId, sectionId, checkpointId } = req.params;
  const { stage } = req.body;

  if (!stage) {
    throw new ApiError(400, "stage is required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find checklist in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found in specified stage");
  }

  // Find section in checklist
  const section = checklist.sections?.find(
    (item) => item._id.toString() === sectionId,
  );

  if (!section) {
    throw new ApiError(404, "Section not found in this checklist");
  }

  // Filter out the checkpoint from section
  section.checkpoints = section.checkpoints.filter(
    (item) => item._id.toString() !== checkpointId,
  );

  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

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

/**
 * UPDATE CHECKPOINT IN TEMPLATE
 * PATCH /api/v1/templates/checkpoints/:checkpointId
 * Updates a checkpoint's text within the template
 * Body: { stage: "stage1" | "stage2" | "stage3", checklistId: string, text: "New question" }
 */
export const updateCheckpointInTemplate = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { stage, checklistId, text, categoryId } = req.body;

  if (!stage || !checklistId || !text) {
    throw new ApiError(400, "stage, checklistId, and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find checklist
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found");
  }

  // Find checkpoint
  const checkpoint = checklist.checkpoints.find(
    (item) => item._id.toString() === checkpointId,
  );

  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  checkpoint.text = text.trim();
  if (categoryId !== undefined) {
    checkpoint.categoryId = categoryId;
  }
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint updated successfully"));
});

/**
 * DELETE CHECKPOINT FROM TEMPLATE
 * DELETE /api/v1/templates/checkpoints/:checkpointId
 * Removes a checkpoint from the template
 * Body: { stage: "stage1" | "stage2" | "stage3", checklistId: string }
 */
export const deleteCheckpointFromTemplate = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { stage, checklistId } = req.body;

  if (!stage || !checklistId) {
    throw new ApiError(400, "stage and checklistId are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find checklist
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist not found");
  }

  // Filter out checkpoint
  checklist.checkpoints = checklist.checkpoints.filter(
    (item) => item._id.toString() !== checkpointId,
  );

  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Checkpoint deleted successfully"));
});

/**
 * SEED TEMPLATE WITH SAMPLE DATA (For Testing/Setup)
 * POST /api/v1/templates/seed
 * Creates a template with sample data if none exists
 */
export const seedTemplate = asyncHandler(async (req, res) => {
  let template = await Template.findOne();

  if (template) {
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

  // Create template with sample data
  template = await Template.create({
    name: "Quality Review Process Template",
    stage1: [
      {
        text: "Planning & Requirements",
        checkpoints: [
          { text: "Project scope documented and approved" },
          { text: "Requirements clearly defined" },
          { text: "Timeline and budget approved" },
        ],
      },
      {
        text: "Team Setup",
        checkpoints: [
          { text: "Team members assigned" },
          { text: "Roles and responsibilities defined" },
          { text: "Communication channels established" },
        ],
      },
    ],
    stage2: [
      {
        text: "Development & Testing",
        checkpoints: [
          { text: "Code review completed" },
          { text: "Unit tests written and passed" },
          { text: "Integration testing done" },
        ],
      },
      {
        text: "Quality Assurance",
        checkpoints: [
          { text: "All bugs documented and fixed" },
          { text: "Performance testing completed" },
          { text: "Security review done" },
        ],
      },
    ],
    stage3: [
      {
        text: "Deployment Preparation",
        checkpoints: [
          { text: "Deployment plan documented" },
          { text: "Rollback plan prepared" },
          { text: "Production environment ready" },
        ],
      },
      {
        text: "Post-Deployment",
        checkpoints: [
          { text: "Deployment successful" },
          { text: "Monitoring and logging active" },
          { text: "User documentation complete" },
        ],
      },
    ],
    modifiedBy: req.user?._id || null,
  });

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

/**
 * UPDATE DEFECT CATEGORIES
 * PATCH /api/v1/templates/defect-categories
 * Updates the defect categories in the template
 * Body: { defectCategories: [{name: string, color?: string}] }
 */
export const updateDefectCategories = asyncHandler(async (req, res) => {
  const { defectCategories } = req.body;

  if (!defectCategories || !Array.isArray(defectCategories)) {
    throw new ApiError(400, "defectCategories array is required");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Ensure each category has a default color if not provided
  template.defectCategories = defectCategories.map((cat) => ({
    name: cat.name,
    color: cat.color || "#2196F3", // Default blue if not provided
  }));
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(
      new ApiResponse(200, template, "Defect categories updated successfully"),
    );
});

/**
 * UPDATE PHASE NAMES
 * PATCH /api/v1/templates/phase-names
 * Updates custom names for phases in the template
 * Body: { phaseNames: { "stage1": "Kickoff Review", "stage2": "Design Phase", ... } }
 */
export const updatePhaseNames = asyncHandler(async (req, res) => {
  const { phaseNames } = req.body;

  if (!phaseNames || typeof phaseNames !== "object") {
    throw new ApiError(400, "phaseNames object is required");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Update phase names in template
  template.phaseNames = new Map(Object.entries(phaseNames));
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Phase names updated successfully"));
});

/**
 * ADD SECTION TO CHECKLIST GROUP IN TEMPLATE
 * POST /api/v1/templates/checklists/:checklistId/sections
 * Adds a section (container for questions) to a checklist group within the template
 * Body: { stage: "stage1" | "stage2" | "stage3", text: "Section Name" }
 */
export const addSectionToChecklist = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { stage, text } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find the checklist (group) in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist group not found in specified stage");
  }

  // Initialize sections array if it doesn't exist
  if (!checklist.sections) {
    checklist.sections = [];
  }

  // Add new section with empty checkpoints array
  checklist.sections.push({ text: text.trim(), checkpoints: [] });
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section added successfully"));
});

/**
 * UPDATE SECTION IN CHECKLIST GROUP IN TEMPLATE
 * PUT /api/v1/templates/checklists/:checklistId/sections/:sectionId
 * Updates the text of a section within a checklist group
 * Body: { stage: "stage1" | "stage2" | "stage3", text: "New Section Name" }
 */
export const updateSectionInChecklist = asyncHandler(async (req, res) => {
  const { checklistId, sectionId } = req.params;
  const { stage, text } = req.body;

  if (!stage || !text) {
    throw new ApiError(400, "stage and text are required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find the checklist (group) in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist group not found");
  }

  // Find section in checklist
  const section = checklist.sections?.find(
    (item) => item._id.toString() === sectionId,
  );

  if (!section) {
    throw new ApiError(404, "Section not found in this checklist group");
  }

  section.text = text.trim();
  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section updated successfully"));
});

/**
 * DELETE SECTION FROM CHECKLIST GROUP IN TEMPLATE
 * DELETE /api/v1/templates/checklists/:checklistId/sections/:sectionId
 * Removes a section from a checklist group
 * Body: { stage: "stage1" | "stage2" | "stage3" }
 */
export const deleteSectionFromChecklist = asyncHandler(async (req, res) => {
  const { checklistId, sectionId } = req.params;
  const { stage } = req.body;

  if (!stage) {
    throw new ApiError(400, "stage is required");
  }

  if (!isValidStage(stage)) {
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found");
  }

  // Find the checklist (group) in specified stage
  const checklist = template[stage]?.find(
    (item) => item._id.toString() === checklistId,
  );

  if (!checklist) {
    throw new ApiError(404, "Checklist group not found");
  }

  // Filter out the section with matching ID
  if (checklist.sections) {
    checklist.sections = checklist.sections.filter(
      (item) => item._id.toString() !== sectionId,
    );
  }

  template.markModified(stage);
  template.modifiedBy = req.user?._id;
  await template.save();

  return res
    .status(200)
    .json(new ApiResponse(200, template, "Section deleted successfully"));
});
