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
      if (!cl._id) { cl._id = new mongoose.Types.ObjectId(); modified = true; }
      if (!Array.isArray(cl.checkpoints)) { cl.checkpoints = []; modified = true; }
      if (!Array.isArray(cl.sections)) { cl.sections = []; modified = true; }
      cl.sections.forEach((sec) => {
        if (!sec._id) { sec._id = new mongoose.Types.ObjectId(); modified = true; }
        if (!Array.isArray(sec.checkpoints)) { sec.checkpoints = []; modified = true; }
        sec.checkpoints.forEach((cp) => {
          if (!cp._id) { cp._id = new mongoose.Types.ObjectId(); modified = true; }
        });
      });
      cl.checkpoints.forEach((cp) => {
        if (!cp._id) { cp._id = new mongoose.Types.ObjectId(); modified = true; }
      });
    });
    if (modified) template.markModified(stage);
  }
  return modified;
}

async function getTemplateSingleton() {
  const template = await Template.findOne();
  if (!template) throw new ApiError(404, "Template not found");
  return template;
}

function validateStage(stage) {
  if (!isValidStage(stage)) throw new ApiError(400, "Invalid stage format. Must be stage1-99");
}

function findChecklist(template, stage, checklistId) {
  if (!Array.isArray(template[stage])) {
    throw new ApiError(404, `Stage ${stage} not found or has no checklists`);
  }
  const checklist = template[stage].find((item) => item._id.toString() === checklistId);
  if (!checklist) throw new ApiError(404, "Checklist not found in specified stage");
  return checklist;
}

function findSection(checklist, sectionId) {
  const section = checklist.sections?.find((item) => item._id.toString() === sectionId);
  if (!section) throw new ApiError(404, "Section not found in this checklist");
  return section;
}

// ── Template CRUD ──

export async function createOrUpdateTemplate(name, userId) {
  let template = await Template.findOne();
  if (template) {
    if (name) template.name = name;
    template.modifiedBy = userId;
    await template.save();
    invalidateTemplate();
    return { template, created: false };
  }
  template = await Template.create({
    name: name || "Default Quality Review Template",
    modifiedBy: userId,
  });
  invalidateTemplate();
  return { template, created: true };
}

export async function getTemplate(stage) {
  return getOrSet(keys.template(stage), async () => {
    const template = await getTemplateSingleton();

    const wasModified = await ensureTemplateConsistency(template);
    if (wasModified) await template.save();

    if (stage) {
      validateStage(stage);
      return {
        _id: template._id, name: template.name, [stage]: template[stage],
        modifiedBy: template.modifiedBy, createdAt: template.createdAt, updatedAt: template.updatedAt,
      };
    }

    return template.toObject ? template.toObject() : JSON.parse(JSON.stringify(template));
  }, TTL.TEMPLATES);
}

export async function resetTemplate() {
  const result = await Template.deleteOne({});
  invalidateTemplate();
  return { deletedCount: result.deletedCount };
}

// ── Checklist (group) management ──

export async function addChecklistToTemplate(stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();

  if (!Array.isArray(template[stage])) template[stage] = [];
  template[stage].push({
    _id: new mongoose.Types.ObjectId(), text: text.trim(), checkpoints: [], sections: [],
  });
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function updateChecklistInTemplate(checklistId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);
  checklist.text = text.trim();
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteChecklistFromTemplate(checklistId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  findChecklist(template, stage, checklistId);

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: { [stage]: { _id: new mongoose.Types.ObjectId(checklistId) } },
      $set: { modifiedBy: userId },
    },
  );
  invalidateTemplate();
  return Template.findOne().lean();
}

// ── Checkpoint (question) management on checklists ──

export async function addCheckpointToTemplate(checklistId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
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

export async function updateCheckpointInTemplate(checkpointId, stage, checklistId, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);
  const checkpoint = checklist.checkpoints.find((item) => item._id.toString() === checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteCheckpointFromTemplate(checkpointId, stage, checklistId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);

  if (!checklist.checkpoints.some((item) => item._id.toString() === checkpointId)) {
    throw new ApiError(404, "Checkpoint not found");
  }

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: { [`${stage}.$[checklist].checkpoints`]: { _id: new mongoose.Types.ObjectId(checkpointId) } },
      $set: { modifiedBy: userId },
    },
    { arrayFilters: [{ "checklist._id": new mongoose.Types.ObjectId(checklistId) }] },
  );
  invalidateTemplate();
  return Template.findOne().lean();
}

// ── Section management ──

export async function addSectionToChecklist(checklistId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);

  if (!checklist.sections) checklist.sections = [];
  checklist.sections.push({ _id: new mongoose.Types.ObjectId(), text: text.trim(), checkpoints: [] });
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function updateSectionInChecklist(checklistId, sectionId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);
  section.text = text.trim();
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteSectionFromChecklist(checklistId, sectionId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);

  if (!(checklist.sections || []).some((item) => item._id.toString() === sectionId)) {
    throw new ApiError(404, "Section not found in this checklist group");
  }

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: { [`${stage}.$[checklist].sections`]: { _id: new mongoose.Types.ObjectId(sectionId) } },
      $set: { modifiedBy: userId },
    },
    { arrayFilters: [{ "checklist._id": new mongoose.Types.ObjectId(checklistId) }] },
  );
  invalidateTemplate();
  return Template.findOne().lean();
}

// ── Checkpoint management on sections ──

export async function addCheckpointToSection(checklistId, sectionId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
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

export async function updateCheckpointInSection(checklistId, sectionId, checkpointId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);
  const checkpoint = section.checkpoints.find((item) => item._id.toString() === checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found in this section");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;
  template.markModified(stage);
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

export async function deleteCheckpointFromSection(checklistId, sectionId, checkpointId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const checklist = findChecklist(template, stage, checklistId);
  const section = findSection(checklist, sectionId);

  if (!section.checkpoints.some((item) => item._id.toString() === checkpointId)) {
    throw new ApiError(404, "Checkpoint not found in this section");
  }

  await Template.collection.updateOne(
    { _id: template._id },
    {
      $pull: {
        [`${stage}.$[checklist].sections.$[section].checkpoints`]: { _id: new mongoose.Types.ObjectId(checkpointId) },
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
  return Template.findOne().lean();
}

// ── Stage management ──

export async function addStageToTemplate(stage, stageName, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();

  if (template[stage] !== undefined) {
    const existingStages = Object.keys(template.toObject()).filter((key) => /^stage\d{1,2}$/.test(key));
    throw new ApiError(400, `${stage} already exists. Available stages: ${existingStages.join(", ")}`);
  }

  const updateObj = { [stage]: [], modifiedBy: userId };
  if (stageName && stageName.trim()) {
    updateObj[`stageNames.${stage}`] = stageName.trim();
  }

  await Template.collection.updateOne({ _id: template._id }, { $set: updateObj });
  invalidateTemplate();
  return Template.findOne().lean();
}

export async function deleteStageFromTemplate(stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();

  if (template[stage] === undefined) {
    const availableStages = Object.keys(template.toObject()).filter((key) => /^stage\d{1,2}$/.test(key));
    throw new ApiError(404, `Stage ${stage} not found. Available stages: ${availableStages.join(", ")}`);
  }

  const unsetObj = { [stage]: "" };
  if (template.stageNames?.[stage]) unsetObj[`stageNames.${stage}`] = "";

  await Template.collection.updateOne(
    { _id: template._id },
    { $unset: unsetObj, $set: { modifiedBy: userId } },
  );
  invalidateTemplate();
  return Template.findOne().lean();
}

export async function getAllStages() {
  return getOrSet(keys.template("allStages"), async () => {
    const template = await getTemplateSingleton();

    const stageKeys = Object.keys(template.toObject())
      .filter((key) => /^stage\d{1,2}$/.test(key))
      .sort((a, b) => parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")));

    const stages = {};
    for (const key of stageKeys) {
      stages[key] = `Phase ${parseInt(key.replace("stage", ""))}`;
    }
    return stages;
  }, TTL.TEMPLATES);
}

// ── Defect categories ──

export async function updateDefectCategories(defectCategories, userId) {
  const template = await getTemplateSingleton();
  template.defectCategories = defectCategories.map((cat) => ({
    name: cat.name,
    color: cat.color || "#2196F3",
  }));
  template.modifiedBy = userId;
  await template.save();
  invalidateTemplate();
  return template;
}

// ── Seed ──

export async function seedTemplate(userId) {
  let template = await Template.findOne();
  if (template) return { template, alreadyExists: true };

  template = await Template.create({
    name: "Quality Review Process Template",
    stage1: [
      { text: "Planning & Requirements", checkpoints: [
        { text: "Project scope documented and approved" },
        { text: "Requirements clearly defined" },
        { text: "Timeline and budget approved" },
      ]},
      { text: "Team Setup", checkpoints: [
        { text: "Team members assigned" },
        { text: "Roles and responsibilities defined" },
        { text: "Communication channels established" },
      ]},
    ],
    stage2: [
      { text: "Development & Testing", checkpoints: [
        { text: "Code review completed" },
        { text: "Unit tests written and passed" },
        { text: "Integration testing done" },
      ]},
      { text: "Quality Assurance", checkpoints: [
        { text: "All bugs documented and fixed" },
        { text: "Performance testing completed" },
        { text: "Security review done" },
      ]},
    ],
    stage3: [
      { text: "Deployment Preparation", checkpoints: [
        { text: "Deployment plan documented" },
        { text: "Rollback plan prepared" },
        { text: "Production environment ready" },
      ]},
      { text: "Post-Deployment", checkpoints: [
        { text: "Deployment successful" },
        { text: "Monitoring and logging active" },
        { text: "User documentation complete" },
      ]},
    ],
    modifiedBy: userId,
  });
  invalidateTemplate();
  return { template, alreadyExists: false };
}
