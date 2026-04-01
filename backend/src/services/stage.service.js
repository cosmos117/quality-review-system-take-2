import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { paginatedResponse } from "../utils/paginate.js";
import { getOrSet, keys, TTL, invalidateStages } from "../utils/cache.js";
import { newId } from "../utils/newId.js";

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
  const project = await prisma.project.findUnique({
    where: { id: projectId },
    select: { created_by: true },
  });
  if (!project) throw new ApiError(404, "Project not found");

  const template = await prisma.template.findFirst();
  if (!template) throw new ApiError(404, "Template not found. Please create a template first.");

  const creatorId = userId || project.created_by;

  const stageData = template.stageData ? (typeof template.stageData === "string" ? JSON.parse(template.stageData) : template.stageData) : {};
  const stageNames = template.stageNames ? (typeof template.stageNames === "string" ? JSON.parse(template.stageNames) : template.stageNames) : {};

  const stageKeys = Object.keys(stageData)
    .filter((key) => /^stage\d{1,2}$/.test(key))
    .sort((a, b) => parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")));

  const stageDefs = stageKeys.map((key) => ({
    name: stageNames[key] || `${key}`,
    key,
  }));

  const stageDocs = [];

  for (const def of stageDefs) {
    const stage = await prisma.stage.create({
      data: {
        id: newId(),
        project_id: projectId,
        stage_name: def.name,
        stage_key: def.key,
        status: "pending",
        created_by: creatorId,
        loopback_count: 0,
        conflict_count: 0,
      },
    });
    stageDocs.push({ doc: stage, key: def.key });
  }

  for (const { doc: stage, key } of stageDocs) {
    const checklists = stageData[key] || [];
    for (const cl of checklists) {
      const checklist = await prisma.checklist.create({
        data: {
          id: newId(),
          stage_id: stage.id,
          created_by: creatorId,
          checklist_name: cl.text,
          description: "",
          status: "draft",
          revision_number: 0,
          answers: {},
        },
      });

      const checkpointDocs = (cl.checkpoints || []).map((cp) => ({
        id: newId(),
        checklistId: checklist.id,
        question: cp.text,
        executorResponse: {},
        reviewerResponse: {},
      }));

      if (checkpointDocs.length > 0) {
        await prisma.checkpoint.createMany({ data: checkpointDocs });
      }
    }

    const groups = mapTemplateGroups(checklists);
    
    // Upsert projectChecklist
    const existingPC = await prisma.projectChecklist.findFirst({
        where: { projectId, stageId: stage.id }
    });
    if (!existingPC) {
        await prisma.projectChecklist.create({
            data: {
                id: newId(),
                projectId,
                stageId: stage.id,
                stage: stage.stage_name,
                groups,
            }
        });
    }
  }

  return stageDocs.map((entry) => entry.doc);
}

async function ensureProjectChecklistsForStages(stages, projectId) {
  try {
    const template = await prisma.template.findFirst();
    const stageData = template?.stageData ? (typeof template.stageData === "string" ? JSON.parse(template.stageData) : template.stageData) : {};
    
    for (const stage of stages) {
      let stageKey = stage.stage_key;
      if (!stageKey) stageKey = deriveStageKey(stage.stage_name);
      
      const stageTemplate = stageKey ? stageData[stageKey] || [] : [];
      const groups = mapTemplateGroups(stageTemplate);
      
      const existingPC = await prisma.projectChecklist.findFirst({
        where: { projectId, stageId: stage.id }
      });
      if (!existingPC) {
          await prisma.projectChecklist.create({
            data: {
                id: newId(),
                projectId,
                stageId: stage.id,
                stage: stage.stage_name,
                groups,
            }
          });
      }
    }
  } catch {
    // Silent failure
  }
}

// ── Service functions ────────────────────────────────────────────────

export async function listStagesForProject(projectId, userId) {
  return getOrSet(keys.stagesForProject(projectId), async () => {
    let stages = await prisma.stage.findMany({
      where: { project_id: projectId },
      orderBy: { createdAt: "asc" },
    });

    if (stages.length === 0) {
      const project = await prisma.project.findUnique({
        where: { id: projectId },
        select: { id: true },
      });
      if (!project) throw new ApiError(404, "Project not found");

      stages = await cloneTemplateToProject(projectId, userId);
    }

    await ensureProjectChecklistsForStages(stages, projectId);

    return paginatedResponse(stages, stages.length, { page: 1, limit: null });
  }, TTL.STAGES);
}

export async function getStageById(id) {
  return getOrSet(keys.stageById(id), async () => {
    const stage = await prisma.stage.findUnique({ where: { id } });
    if (!stage) throw new ApiError(404, "Stage not found");
    return stage;
  }, TTL.STAGES);
}

export async function createStage(projectId, { stage_name, stage_key, description, status }, createdBy) {
  const stage = await prisma.stage.create({
    data: {
      id: newId(),
      project_id: projectId,
      stage_name,
      stage_key: stage_key || null,
      description,
      status,
      created_by: createdBy,
    },
  });

  try {
    const template = await prisma.template.findFirst();
    let key = stage_key;
    if (!key) key = deriveStageKey(stage_name);
    
    const stageData = template?.stageData ? (typeof template.stageData === "string" ? JSON.parse(template.stageData) : template.stageData) : {};
    const groups = key ? mapTemplateGroups(stageData[key] || []) : [];
    
    await prisma.projectChecklist.create({
        data: {
            id: newId(),
            projectId,
            stageId: stage.id,
            stage: stage.stage_name,
            groups,
        }
    });

  } catch {
    // Silent failure
  }

  invalidateStages(projectId);
  return stage;
}

export async function updateStage(id, { stage_name, description, status }) {
  const data = {};
  if (typeof stage_name === "string") data.stage_name = stage_name;
  if (typeof description === "string") data.description = description;
  if (typeof status === "string") data.status = status;

  if (Object.keys(data).length === 0) {
    throw new ApiError(400, "No valid fields provided to update");
  }

  const stage = await prisma.stage.update({
    where: { id },
    data,
  });
  if (!stage) throw new ApiError(404, "Stage not found");
  invalidateStages(stage.project_id);
  return stage;
}

export async function deleteStage(id) {
  const stage = await prisma.stage.findUnique({ where: { id } });
  if (!stage) throw new ApiError(404, "Stage not found");
  
  await prisma.stage.delete({ where: { id } });
  
  invalidateStages(stage.project_id);
  return stage;
}

export async function migrateStageCounters() {
  const { count } = await prisma.stage.updateMany({
    data: { loopback_count: 0, conflict_count: 0 },
  });
  return count;
}
