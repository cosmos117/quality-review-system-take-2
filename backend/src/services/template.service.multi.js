import mongoose from "mongoose";
import Template from "../models/template.models.js";
import { ApiError } from "../utils/ApiError.js";
import { getOrSet, keys, TTL, invalidateTemplate } from "../utils/cache.js";

const isValidStage = (stage) => /^stage\d{1,2}$/.test(stage);

async function ensureTemplateConsistency(template) {
  let modified = false;
  const doc = template.toObject ? template.toObject() : template;
  const stageKeys = Object.keys(doc).filter((k) => /^stage\d{1,2}$/.test(k));

  for (const stage of stageKeys) {
    const arr = template[stage];
    if (!Array.isArray(arr)) continue;
    arr.forEach((cl) => {
      if (!cl._id) {
        cl._id = new mongoose.Types.ObjectId();
        modified = true;
      }
      if (!Array.isArray(cl.checkpoints)) {
        cl.checkpoints = [];
        modified = true;
      }
      if (!Array.isArray(cl.sections)) {
        cl.sections = [];
        modified = true;
      }
      cl.sections.forEach((sec) => {
        if (!sec._id) {
          sec._id = new mongoose.Types.ObjectId();
          modified = true;
        }
        if (!Array.isArray(sec.checkpoints)) {
          sec.checkpoints = [];
          modified = true;
        }
        sec.checkpoints.forEach((cp) => {
          if (!cp._id) {
            cp._id = new mongoose.Types.ObjectId();
            modified = true;
          }
        });
      });
      cl.checkpoints.forEach((cp) => {
        if (!cp._id) {
          cp._id = new mongoose.Types.ObjectId();
          modified = true;
        }
      });
    });
    if (modified) template.markModified(stage);
  }
  return modified;
}

async function getTemplateByName(templateName) {
  const template = await Template.findOne({ templateName });
  if (!template)
    throw new ApiError(404, `Template "${templateName}" not found`);
  return template;
}

function validateStage(stage) {
  if (!isValidStage(stage))
    throw new ApiError(400, "Invalid stage format. Must be stage1-99");
}

function findChecklist(template, stage, checklistId) {
  if (!Array.isArray(template[stage])) {
    throw new ApiError(404, `Stage ${stage} not found or has no checklists`);
  }
  const checklist = template[stage].find(
    (item) => item._id.toString() === checklistId,
  );
  if (!checklist)
    throw new ApiError(404, "Checklist not found in specified stage");
  return checklist;
}

function findSection(checklist, sectionId) {
  const section = checklist.sections?.find(
    (item) => item._id.toString() === sectionId,
  );
  if (!section) throw new ApiError(404, "Section not found in this checklist");
  return section;
}

// ── Template CRUD ──

/**
 * Create a new template with a unique name
 */
export async function createTemplate(
  templateName,
  displayName,
  description,
  userId,
) {
  if (!templateName || !templateName.trim()) {
    throw new ApiError(400, "templateName is required");
  }

  const existing = await Template.findOne({
    templateName: templateName.trim(),
  });
  if (existing) {
    throw new ApiError(
      409,
      `Template with name "${templateName}" already exists`,
    );
  }

  const template = await Template.create({
    templateName: templateName.trim(),
    name: displayName || templateName.trim(),
    description: description || "",
    modifiedBy: userId,
  });

  invalidateTemplate();
  return template;
}

/**
 * Save a complete template payload as a named template.
 * Payload may include dynamic stageN arrays, stageNames and defectCategories.
 */
export async function saveTemplatePayload(
  templateName,
  displayName,
  description,
  templateData,
  userId,
) {
  const normalizedTemplateName = (templateName || "").trim();
  if (!normalizedTemplateName) {
    throw new ApiError(400, "templateName is required");
  }

  const existing = await Template.findOne({
    templateName: normalizedTemplateName,
  });
  if (existing) {
    throw new ApiError(
      409,
      `Template with name "${normalizedTemplateName}" already exists`,
    );
  }

  const payload = {
    templateName: normalizedTemplateName,
    name: (displayName || normalizedTemplateName).trim(),
    description: (description || "").trim(),
    isActive: true,
    modifiedBy: userId,
  };

  if (
    templateData.stageNames &&
    typeof templateData.stageNames === "object" &&
    !Array.isArray(templateData.stageNames)
  ) {
    payload.stageNames = templateData.stageNames;
  }

  if (Array.isArray(templateData.defectCategories)) {
    payload.defectCategories = templateData.defectCategories.map((cat) => ({
      name: cat?.name,
      color: cat?.color || "#2196F3",
      keywords: Array.isArray(cat?.keywords) ? cat.keywords : [],
    }));
  }

  // Copy dynamic stageN fields exactly as stored in existing template format
  for (const [key, value] of Object.entries(templateData)) {
    if (/^stage\d{1,2}$/.test(key) && Array.isArray(value)) {
      payload[key] = value;
    }
  }

  const template = await Template.create(payload);
  invalidateTemplate();
  return template;
}

/**
 * Update an existing named template with a full template payload.
 */
export async function updateTemplatePayload(
  templateName,
  displayName,
  description,
  templateData,
  userId,
) {
  const normalizedTemplateName = (templateName || "").trim();
  if (!normalizedTemplateName) {
    throw new ApiError(400, "templateName is required");
  }

  const existing = await Template.findOne({
    templateName: normalizedTemplateName,
  });
  if (!existing) {
    throw new ApiError(
      404,
      `Template with name "${normalizedTemplateName}" not found`,
    );
  }

  const existingObj = existing.toObject({ flattenMaps: true });
  const existingStageKeys = Object.keys(existingObj).filter((key) =>
    /^stage\d{1,2}$/.test(key),
  );

  const payloadStageKeys = Object.keys(templateData || {}).filter((key) =>
    /^stage\d{1,2}$/.test(key),
  );

  const setObj = {
    modifiedBy: userId,
  };

  if (displayName && displayName.trim()) {
    setObj.name = displayName.trim();
  }
  if (description !== undefined) {
    setObj.description = (description || "").trim();
  }

  if (
    templateData.stageNames &&
    typeof templateData.stageNames === "object" &&
    !Array.isArray(templateData.stageNames)
  ) {
    setObj.stageNames = templateData.stageNames;
  }

  if (Array.isArray(templateData.defectCategories)) {
    setObj.defectCategories = templateData.defectCategories.map((cat) => ({
      name: cat?.name,
      color: cat?.color || "#2196F3",
      keywords: Array.isArray(cat?.keywords) ? cat.keywords : [],
    }));
  }

  for (const key of payloadStageKeys) {
    const value = templateData[key];
    if (Array.isArray(value)) {
      setObj[key] = value;
    }
  }

  const unsetObj = {};
  for (const key of existingStageKeys) {
    if (!payloadStageKeys.includes(key)) {
      unsetObj[key] = "";
    }
  }

  const update = { $set: setObj };
  if (Object.keys(unsetObj).length > 0) {
    update.$unset = unsetObj;
  }

  await Template.updateOne({ _id: existing._id }, update);
  invalidateTemplate();

  return Template.findOne({ templateName: normalizedTemplateName }).lean();
}

/**
 * Get all template names for dropdown (returns array of { templateName, name, description })
 */
export async function getAllTemplateNames(isActive = true) {
  return getOrSet(
    keys.template("allNames"),
    async () => {
      const query = isActive ? { isActive: true } : {};
      const templates = await Template.find(query)
        .select({
          templateName: 1,
          name: 1,
          description: 1,
          isActive: 1,
          createdAt: 1,
        })
        .sort({ createdAt: -1 });

      return templates.map((t) => ({
        templateName: t.templateName,
        name: t.name,
        description: t.description,
        isActive: t.isActive,
        createdAt: t.createdAt,
      }));
    },
    TTL.TEMPLATES,
  );
}

/**
 * Get complete template by name including all stages/phases
 */
export async function getTemplate(templateName, stage) {
  return getOrSet(
    keys.template(`${templateName}:${stage || "all"}`),
    async () => {
      const template = await getTemplateByName(templateName);

      const wasModified = await ensureTemplateConsistency(template);
      if (wasModified) await template.save();

      if (stage) {
        validateStage(stage);
        return {
          _id: template._id,
          templateName: template.templateName,
          name: template.name,
          description: template.description,
          [stage]: template[stage],
          modifiedBy: template.modifiedBy,
          createdAt: template.createdAt,
          updatedAt: template.updatedAt,
        };
      }

      return template.toObject
        ? template.toObject({ flattenMaps: true })
        : JSON.parse(JSON.stringify(template));
    },
    TTL.TEMPLATES,
  );
}

/**
 * Update template name or metadata
 */
export async function updateTemplateMetadata(templateName, updates, userId) {
  const template = await getTemplateByName(templateName);

  if (updates.name) template.name = updates.name;
  if (updates.description !== undefined)
    template.description = updates.description;
  if (updates.isActive !== undefined) template.isActive = updates.isActive;
  if (
    updates.stageNames &&
    typeof updates.stageNames === "object" &&
    !Array.isArray(updates.stageNames)
  ) {
    template.stageNames = {
      ...(template.stageNames?.toObject?.() || template.stageNames || {}),
      ...updates.stageNames,
    };
    template.markModified("stageNames");
  }

  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

/**
 * Delete entire template
 */
export async function deleteTemplate(templateName) {
  const template = await getTemplateByName(templateName);
  await Template.deleteOne({ _id: template._id });
  invalidateTemplate();
  return { deletedCount: 1, templateName };
}

/**
 * Duplicate a template with a new name
 */
export async function duplicateTemplate(
  sourceTemplateName,
  newTemplateName,
  userId,
) {
  const sourceTemplate = await getTemplateByName(sourceTemplateName);

  const existing = await Template.findOne({ templateName: newTemplateName });
  if (existing) {
    throw new ApiError(
      409,
      `Template with name "${newTemplateName}" already exists`,
    );
  }

  const templateData = sourceTemplate.toObject();
  delete templateData._id;
  delete templateData.createdAt;
  delete templateData.updatedAt;

  const newTemplate = await Template.create({
    ...templateData,
    templateName: newTemplateName,
    name: `${sourceTemplate.name} (Copy)`,
    modifiedBy: userId,
  });

  invalidateTemplate();
  return newTemplate;
}

// ── Checklist (group) management ──

export async function addChecklistToTemplate(
  templateName,
  stage,
  text,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);

  if (!Array.isArray(template[stage])) template[stage] = [];
  template[stage].push({
    _id: new mongoose.Types.ObjectId(),
    text: text.trim(),
    checkpoints: [],
    sections: [],
  });
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function updateChecklistInTemplate(
  templateName,
  checklistId,
  stage,
  text,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);
  checklist.text = text.trim();
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteChecklistFromTemplate(
  templateName,
  checklistId,
  stage,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  findChecklist(template, stage, checklistId);

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: { [stage]: { _id: new mongoose.Types.ObjectId(checklistId) } },
      $set: { modifiedBy: userId },
    },
  );
  invalidateTemplate();
  return Template.findOne({ templateName }).lean();
}

// ── Checkpoint (question) management on checklists ──

export async function addCheckpointToTemplate(
  templateName,
  checklistId,
  stage,
  text,
  categoryId,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);

  const cpData = { _id: new mongoose.Types.ObjectId(), text: text.trim() };
  if (categoryId) cpData.categoryId = categoryId;
  checklist.checkpoints.push(cpData);
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function updateCheckpointInTemplate(
  templateName,
  checkpointId,
  stage,
  checklistId,
  text,
  categoryId,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);
  const checkpoint = checklist.checkpoints.find(
    (item) => item._id.toString() === checkpointId,
  );
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteCheckpointFromTemplate(
  templateName,
  checkpointId,
  stage,
  checklistId,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);

  if (
    !checklist.checkpoints.some((item) => item._id.toString() === checkpointId)
  ) {
    throw new ApiError(404, "Checkpoint not found");
  }

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: {
        [`${stage}.$[checklist].checkpoints`]: {
          _id: new mongoose.Types.ObjectId(checkpointId),
        },
      },
      $set: { modifiedBy: userId },
    },
    {
      arrayFilters: [
        { "checklist._id": new mongoose.Types.ObjectId(checklistId) },
      ],
    },
  );
  invalidateTemplate();
  return Template.findOne({ templateName }).lean();
}

// ── Section management ──

export async function addSectionToChecklist(
  templateName,
  checklistId,
  stage,
  text,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);

  if (!checklist.sections) checklist.sections = [];
  checklist.sections.push({
    _id: new mongoose.Types.ObjectId(),
    text: text.trim(),
    checkpoints: [],
  });
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function updateSectionInChecklist(
  templateName,
  checklistId,
  sectionId,
  stage,
  text,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);
  section.text = text.trim();
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteSectionFromChecklist(
  templateName,
  checklistId,
  sectionId,
  stage,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);

  if (
    !(checklist.sections || []).some(
      (item) => item._id.toString() === sectionId,
    )
  ) {
    throw new ApiError(404, "Section not found in this checklist group");
  }

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: {
        [`${stage}.$[checklist].sections`]: {
          _id: new mongoose.Types.ObjectId(sectionId),
        },
      },
      $set: { modifiedBy: userId },
    },
    {
      arrayFilters: [
        { "checklist._id": new mongoose.Types.ObjectId(checklistId) },
      ],
    },
  );
  invalidateTemplate();
  return Template.findOne({ templateName }).lean();
}

// ── Checkpoint management on sections ──

export async function addCheckpointToSection(
  templateName,
  checklistId,
  sectionId,
  stage,
  text,
  categoryId,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const cpData = { _id: new mongoose.Types.ObjectId(), text: text.trim() };
  if (categoryId) cpData.categoryId = categoryId;
  section.checkpoints.push(cpData);
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function updateCheckpointInSection(
  templateName,
  checklistId,
  sectionId,
  checkpointId,
  stage,
  text,
  categoryId,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);
  const checkpoint = section.checkpoints.find(
    (item) => item._id.toString() === checkpointId,
  );
  if (!checkpoint)
    throw new ApiError(404, "Checkpoint not found in this section");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteCheckpointFromSection(
  templateName,
  checklistId,
  sectionId,
  checkpointId,
  stage,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);

  if (
    !section.checkpoints.some((item) => item._id.toString() === checkpointId)
  ) {
    throw new ApiError(404, "Checkpoint not found in this section");
  }

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: {
        [`${stage}.$[checklist].sections.$[section].checkpoints`]: {
          _id: new mongoose.Types.ObjectId(checkpointId),
        },
      },
      $set: { modifiedBy: userId },
    },
    {
      arrayFilters: [
        { "checklist._id": new mongoose.Types.ObjectId(checklistId) },
        { "section._id": new mongoose.Types.ObjectId(sectionId) },
      ],
    },
  );
  invalidateTemplate();
  return Template.findOne({ templateName }).lean();
}

// ── Stage management ──

export async function addStageToTemplate(
  templateName,
  stage,
  stageName,
  userId,
) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);

  if (template[stage] !== undefined) {
    const existingStages = Object.keys(template.toObject()).filter((key) =>
      /^stage\d{1,2}$/.test(key),
    );
    throw new ApiError(
      400,
      `${stage} already exists. Available stages: ${existingStages.join(", ")}`,
    );
  }

  const updateObj = { [stage]: [], modifiedBy: userId };
  if (stageName && stageName.trim()) {
    updateObj[`stageNames.${stage}`] = stageName.trim();
  }

  await Template.collection.updateOne(
    { _id: template._id },
    { $set: updateObj },
  );
  invalidateTemplate();
  return Template.findOne({ templateName }).lean();
}

export async function deleteStageFromTemplate(templateName, stage, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);

  if (template[stage] === undefined) {
    const availableStages = Object.keys(template.toObject()).filter((key) =>
      /^stage\d{1,2}$/.test(key),
    );
    throw new ApiError(
      404,
      `Stage ${stage} not found. Available stages: ${availableStages.join(", ")}`,
    );
  }

  const unsetObj = { [stage]: "" };
  if (template.stageNames?.[stage]) unsetObj[`stageNames.${stage}`] = "";

  await Template.collection.updateOne(
    { _id: template._id },
    { $unset: unsetObj, $set: { modifiedBy: userId } },
  );
  invalidateTemplate();
  return Template.findOne({ templateName }).lean();
}

export async function getAllStages(templateName) {
  return getOrSet(
    keys.template(`${templateName}:allStages`),
    async () => {
      const template = await getTemplateByName(templateName);

      const stageKeys = Object.keys(template.toObject())
        .filter((key) => /^stage\d{1,2}$/.test(key))
        .sort(
          (a, b) =>
            parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")),
        );

      const stages = {};
      for (const key of stageKeys) {
        stages[key] =
          template.stageNames?.[key] ||
          `Phase ${parseInt(key.replace("stage", ""))}`;
      }
      return stages;
    },
    TTL.TEMPLATES,
  );
}

// ── Defect categories ──

export async function updateDefectCategories(
  templateName,
  defectCategories,
  userId,
) {
  const template = await getTemplateByName(templateName);
  template.defectCategories = defectCategories.map((cat) => ({
    name: cat.name,
    color: cat.color || "#2196F3",
    keywords: cat.keywords || [],
  }));
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

// ── Seed ──

/**
 * Create sample templates for testing
 */
export async function seedSampleTemplates(userId) {
  const existing = await Template.countDocuments();
  if (existing > 0) {
    return { message: "Templates already exist", count: existing };
  }

  const fealTemplate = await Template.create({
    templateName: "FEA_Checklist",
    name: "FEA Checklist",
    description: "Finite Element Analysis quality review template",
    stage1: [
      {
        text: "Model Setup",
        checkpoints: [
          { text: "Geometry imported correctly" },
          { text: "Material properties defined" },
          { text: "Boundary conditions applied" },
        ],
      },
      {
        text: "Meshing",
        checkpoints: [
          { text: "Mesh density appropriate" },
          { text: "Element quality verified" },
          { text: "Refinement zones checked" },
        ],
      },
    ],
    stage2: [
      {
        text: "Analysis Execution",
        checkpoints: [
          { text: "Solver parameters verified" },
          { text: "Convergence criteria set" },
          { text: "Run time reasonable" },
        ],
      },
    ],
    modifiedBy: userId,
  });

  const cfmTemplate = await Template.create({
    templateName: "CFM_Checklist",
    name: "CFM Checklist",
    description: "Computational Fluid Mechanics review template",
    stage1: [
      {
        text: "Domain Setup",
        checkpoints: [
          { text: "Domain geometry defined" },
          { text: "Inlet/outlet conditions set" },
          { text: "Wall properties applied" },
        ],
      },
    ],
    stage2: [
      {
        text: "Solution",
        checkpoints: [
          { text: "Residuals converged" },
          { text: "Mass balance verified" },
          { text: "Results physically reasonable" },
        ],
      },
    ],
    modifiedBy: userId,
  });

  invalidateTemplate();
  return { created: 2, templates: [fealTemplate, cfmTemplate] };
}
