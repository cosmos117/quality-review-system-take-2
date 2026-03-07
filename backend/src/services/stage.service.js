import mongoose from "mongoose";
import Stage from "../models/stage.models.js";
import Project from "../models/project.models.js";
import Template from "../models/template.models.js";
import Checklist from "../models/checklist.models.js";
import Checkpoint from "../models/checkpoint.models.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import { ApiError } from "../utils/ApiError.js";
import { paginatedResponse } from "../utils/paginate.js";
import { getOrSet, keys, TTL, invalidateStages } from "../utils/cache.js";

// ── Helpers ──────────────────────────────────────────────────────────

const deriveStageKey = (stageName = "") => {
  const lower = stageName.toLowerCase();
  const match = lower.match(/(?:phase|stage)\s*(\d{1,2})/);
  if (match) return `stage${parseInt(match[1])}`;
  return null;
};

const mapTemplateGroups = (stageTemplate = []) => {
  return stageTemplate.map((group) => ({
    groupName: (group?.text || "").trim(),
    questions: (group?.checkpoints || []).map((cp) => ({
      text: (cp?.text || "").trim(),
      executorAnswer: null,
      executorRemark: "",
      reviewerStatus: null,
      reviewerRemark: "",
    })),
    sections: (group?.sections || []).map((sec) => ({
      sectionName: (sec?.text || "").trim(),
      questions: (sec?.checkpoints || []).map((cp) => ({
        text: (cp?.text || "").trim(),
        executorAnswer: null,
        executorRemark: "",
        reviewerStatus: null,
        reviewerRemark: "",
      })),
    })),
  }));
};

async function cloneTemplateToProject(projectId, userId) {
  const project = await Project.findById(projectId).select("created_by").populate("created_by", "_id").lean();
  if (!project) throw new ApiError(404, "Project not found");

  const template = await Template.findOne().lean();
  if (!template) throw new ApiError(404, "Template not found. Please create a template first.");

  const creatorId = userId || project.created_by?._id;

  const stageKeys = Object.keys(template)
    .filter((key) => /^stage\d{1,2}$/.test(key))
    .sort((a, b) => parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")));

  const stageNames = template.stageNames || {};
  const stageDefs = stageKeys.map((key) => ({
    name: stageNames[key] || `${key}`,
    key,
  }));

  const stageDocs = [];

  for (const def of stageDefs) {
    const stage = await Stage.create({
      project_id: projectId,
      stage_name: def.name,
      stage_key: def.key,
      status: "pending",
      created_by: creatorId,
      loopback_count: 0,
      conflict_count: 0,
    });
    stageDocs.push({ doc: stage, key: def.key });
  }

  for (const { doc: stage, key } of stageDocs) {
    const checklists = template[key] || [];
    for (const cl of checklists) {
      const checklist = await Checklist.create({
        stage_id: stage._id,
        created_by: creatorId,
        checklist_name: cl.text,
        description: "",
        status: "draft",
        revision_number: 0,
        answers: {},
      });

      const checkpointDocs = (cl.checkpoints || []).map((cp) => ({
        checklistId: checklist._id,
        question: cp.text,
        executorResponse: {},
        reviewerResponse: {},
      }));
      if (checkpointDocs.length > 0) {
        await Checkpoint.insertMany(checkpointDocs);
      }
    }

    const groups = mapTemplateGroups(checklists);
    await ProjectChecklist.findOneAndUpdate(
      { projectId, stageId: stage._id },
      {
        $setOnInsert: {
          projectId,
          stageId: stage._id,
          stage: stage.stage_name,
          groups,
        },
      },
      { upsert: true, new: true },
    );
  }

  return stageDocs.map((entry) => entry.doc);
}

async function ensureProjectChecklistsForStages(stages, projectId) {
  try {
    const template = await Template.findOne().lean();
    for (const stage of stages) {
      let stageKey = stage.stage_key;
      if (!stageKey) stageKey = deriveStageKey(stage.stage_name);
      const stageTemplate = stageKey ? template?.[stageKey] || [] : [];
      const groups = mapTemplateGroups(stageTemplate);
      await ProjectChecklist.findOneAndUpdate(
        { projectId, stageId: stage._id },
        {
          $setOnInsert: {
            projectId,
            stageId: stage._id,
            stage: stage.stage_name,
            groups,
          },
        },
        { upsert: true },
      );
    }
  } catch {
    // Silent failure
  }
}

// ── Service functions ────────────────────────────────────────────────

export async function listStagesForProject(projectId, userId) {
  return getOrSet(keys.stagesForProject(projectId), async () => {
    let stages = await Stage.find({ project_id: projectId }).sort({ createdAt: 1 }).lean();

    if (stages.length === 0) {
      const project = await Project.findById(projectId).select("_id").lean();
      if (!project) throw new ApiError(404, "Project not found");

      stages = await cloneTemplateToProject(projectId, userId);
      stages = stages.map((s) => {
        const obj = s.toObject ? s.toObject() : s;
        return { ...obj, loopback_count: obj.loopback_count || 0, conflict_count: obj.conflict_count || 0 };
      });
    }

    stages = stages.map((stage) => {
      const obj = stage.toObject ? stage.toObject() : stage;
      return {
        ...obj,
        loopback_count: obj.loopback_count ?? 0,
        conflict_count: obj.conflict_count ?? 0,
      };
    });

    await ensureProjectChecklistsForStages(stages, projectId);

    return paginatedResponse(stages, stages.length, { page: 1, limit: null });
  }, TTL.STAGES);
}

export async function getStageById(id) {
  return getOrSet(keys.stageById(id), async () => {
    const stage = await Stage.findById(id).lean();
    if (!stage) throw new ApiError(404, "Stage not found");
    return stage;
  }, TTL.STAGES);
}

export async function createStage(projectId, { stage_name, stage_key, description, status }, createdBy) {
  const stage = await Stage.create({
    project_id: projectId,
    stage_name,
    stage_key: stage_key || null,
    description,
    status,
    created_by: createdBy,
  });

  try {
    const template = await Template.findOne().lean();
    let key = stage_key;
    if (!key) key = deriveStageKey(stage_name);
    const groups = key ? mapTemplateGroups(template?.[key] || []) : [];
    await ProjectChecklist.findOneAndUpdate(
      { projectId, stageId: stage._id },
      {
        $setOnInsert: {
          projectId,
          stageId: stage._id,
          stage: stage.stage_name,
          groups,
        },
      },
      { upsert: true },
    );
  } catch {
    // Silent failure
  }

  invalidateStages(projectId);
  return stage;
}

export async function updateStage(id, { stage_name, description, status }) {
  const update = {};
  if (typeof stage_name === "string") update.stage_name = stage_name;
  if (typeof description === "string") update.description = description;
  if (typeof status === "string") update.status = status;

  if (Object.keys(update).length === 0) {
    throw new ApiError(400, "No valid fields provided to update");
  }

  const stage = await Stage.findByIdAndUpdate(id, { $set: update }, { new: true, runValidators: true }).lean();
  if (!stage) throw new ApiError(404, "Stage not found");
  invalidateStages(stage.project_id?.toString());
  return stage;
}

export async function deleteStage(id) {
  const deleted = await Stage.findByIdAndDelete(id);
  if (!deleted) throw new ApiError(404, "Stage not found");
  invalidateStages(deleted.project_id?.toString());
  return deleted;
}

export async function migrateStageCounters() {
  return Stage.updateMany(
    { $or: [{ loopback_count: { $exists: false } }, { conflict_count: { $exists: false } }] },
    { $set: { loopback_count: 0, conflict_count: 0 } },
  );
}
