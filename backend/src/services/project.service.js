import Project from "../models/project.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";
import Checklist from "../models/checklist.models.js";
import Checkpoint from "../models/checkpoint.models.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistAnswer from "../models/checklistAnswer.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import ChecklistTransaction from "../models/checklistTransaction.models.js";
import { deleteImagesByFileIds } from "../gridfs.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";
import { ApiError } from "../utils/ApiError.js";

// ── Helpers ──────────────────────────────────────────────────────────

async function syncCheckpointsWithTemplate(projectId) {
  try {
    const template = await Template.findOne();
    if (!template) return;

    const stages = await Stage.find({ project_id: projectId });

    const deriveStageKeyFromName = (stageName) => {
      const match = stageName.toLowerCase().match(/(?:phase|stage)\s*(\d{1,2})/);
      return match ? `stage${parseInt(match[1])}` : null;
    };

    for (const stage of stages) {
      const templateStageKey = deriveStageKeyFromName(stage.stage_name);
      if (!templateStageKey) continue;

      const templateChecklists = template[templateStageKey] || [];
      const checklists = await Checklist.find({ stage_id: stage._id });

      for (const checklist of checklists) {
        const templateChecklist = templateChecklists.find(
          (tc) => tc.text === checklist.checklist_name,
        );
        if (!templateChecklist) continue;

        for (const checkpoint of checklist.checkpoints || []) {
          const templateCheckpoint = templateChecklist.checkpoints?.find(
            (tcp) => tcp.text === checkpoint.question,
          );
          if (templateCheckpoint?.categoryId) {
            await Checkpoint.updateOne(
              { _id: checkpoint._id },
              { categoryId: templateCheckpoint.categoryId },
            );
          }
        }
      }
    }
  } catch {
    // Don't throw
  }
}

async function createStagesAndChecklistsFromTemplate(projectId) {
  try {
    const template = await Template.findOne();
    if (!template) return;

    const stageKeys = Object.keys(template.toObject())
      .filter((key) => /^stage\d{1,2}$/.test(key))
      .sort((a, b) => parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")));

    const stageNames = template.stageNames || {};

    for (const stageKey of stageKeys) {
      const stageNum = parseInt(stageKey.replace("stage", ""));
      const stageName = stageNames[stageKey] || `Phase ${stageNum}`;

      const stage = await Stage.create({
        project_id: projectId,
        stage_name: stageName,
        stage_key: stageKey,
        status: "pending",
      });

      const templateGroups = template[stageKey] || [];
      const groups = templateGroups.map((tg) => ({
        groupName: tg.text,
        questions: (tg.checkpoints || []).map((cp) => ({
          text: cp.text,
          executorAnswer: null,
          executorRemark: "",
          reviewerStatus: null,
          reviewerRemark: "",
        })),
        sections: (tg.sections || []).map((section) => ({
          sectionName: section.text,
          questions: (section.checkpoints || []).map((cp) => ({
            text: cp.text,
            executorAnswer: null,
            executorRemark: "",
            reviewerStatus: null,
            reviewerRemark: "",
          })),
        })),
      }));

      await ProjectChecklist.create({
        projectId,
        stageId: stage._id,
        stage: stageKey,
        groups,
      });
    }
  } catch {
    // Don't throw
  }
}

// ── Service functions ────────────────────────────────────────────────

export async function getAllProjects(query) {
  const { page, limit, skip } = parsePagination(query);
  const filter = {};
  const total = await Project.countDocuments(filter);

  let q = Project.find(filter)
    .populate("created_by", "name email")
    .sort({ createdAt: -1 })
    .lean();

  if (limit) q = q.skip(skip).limit(limit);

  const projects = await q;
  return paginatedResponse(projects, total, { page, limit });
}

export async function getProjectsForUser(userId) {
  const memberships = await ProjectMembership.find({ user_id: userId })
    .populate({
      path: "project_id",
      populate: { path: "created_by", select: "name email" },
    })
    .populate("role", "role_name")
    .lean();

  const projectIds = memberships
    .filter((m) => m.project_id)
    .map((m) => m.project_id._id);

  const allMemberships = await ProjectMembership.find({
    project_id: { $in: projectIds },
  }).populate("role", "role_name").lean();

  const projectMembersMap = {};
  for (const m of allMemberships) {
    const pid = m.project_id.toString();
    if (!projectMembersMap[pid]) projectMembersMap[pid] = [];
    projectMembersMap[pid].push(m.user_id);
  }

  return memberships
    .filter((m) => m.project_id)
    .map((m) => {
      const project = m.project_id;
      const pid = project._id.toString();
      return {
        ...project,
        userRole: m.role?.role_name || null,
        membershipId: m._id,
        assignedEmployees: projectMembersMap[pid] || [],
      };
    });
}

export async function getProjectById(id) {
  const project = await Project.findById(id).populate("created_by", "name email").lean();
  if (!project) throw new ApiError(404, "Project not found");
  return project;
}

export async function createProject(data) {
  const project = await Project.create(data);
  return Project.findById(project._id).populate("created_by", "name email");
}

export async function updateProject(projectId, data, requestingUserId) {
  const existing = await Project.findById(projectId);
  if (!existing) throw new ApiError(404, "Project not found");

  const prevStatus = existing.status;
  const {
    project_no, internal_order_no, project_name, description,
    status, priority, start_date, end_date,
    isReviewApplicable, reviewApplicableRemark,
  } = data;

  const requestedStatus = typeof status === "string" ? status : existing.status;
  if (prevStatus === "pending" && requestedStatus === "in_progress") {
    const assigned = await ProjectMembership.findOne({
      project_id: existing._id,
      user_id: requestingUserId,
    });
    if (!assigned) throw new ApiError(403, "Only assigned users can start this project");
  }

  existing.project_no = project_no ?? existing.project_no;
  existing.internal_order_no = internal_order_no ?? existing.internal_order_no;
  if (typeof project_name === "string") existing.project_name = project_name;
  if (typeof description === "string") existing.description = description;
  if (typeof status === "string") existing.status = status;
  if (typeof priority === "string") existing.priority = priority;
  if (start_date) existing.start_date = start_date;
  if (end_date) existing.end_date = end_date;
  if (typeof isReviewApplicable === "string" || isReviewApplicable === null)
    existing.isReviewApplicable = isReviewApplicable;
  if (typeof reviewApplicableRemark === "string" || reviewApplicableRemark === null)
    existing.reviewApplicableRemark = reviewApplicableRemark;

  await existing.save();

  const project = await Project.findById(existing._id).populate("created_by", "name email");

  if (prevStatus === "pending" && existing.status === "in_progress") {
    const existingStagesCount = await Stage.countDocuments({ project_id: existing._id });
    if (existingStagesCount === 0) {
      await createStagesAndChecklistsFromTemplate(existing._id);
    }
  }

  return project;
}

export async function syncProjectCheckpointCategories(projectId) {
  await syncCheckpointsWithTemplate(projectId);
}

export async function getProjectStages(projectId) {
  const stages = await Stage.find({ project_id: projectId }).sort({ createdAt: 1 }).lean();
  return stages.map((stage) => ({
    _id: stage._id,
    stage_name: stage.stage_name,
    stage_key: stage.stage_key,
    status: stage.status,
    loopback_count: stage.loopback_count || 0,
    conflict_count: stage.conflict_count || 0,
  }));
}

export async function deleteProject(projectId) {
  const project = await Project.findById(projectId);
  if (!project) throw new ApiError(404, "Project not found");

  const deletionStats = {};

  const deletedMemberships = await ProjectMembership.deleteMany({ project_id: projectId });
  deletionStats.memberships = deletedMemberships.deletedCount;

  const deletedAnswers = await ChecklistAnswer.deleteMany({ project_id: projectId });
  deletionStats.checklistAnswers = deletedAnswers.deletedCount;

  const deletedApprovals = await ChecklistApproval.deleteMany({ project_id: projectId });
  deletionStats.checklistApprovals = deletedApprovals.deletedCount;

  // Collect and delete all images
  try {
    const projectChecklists = await ProjectChecklist.find({ projectId });
    const allFileIds = [];

    for (const checklist of projectChecklists) {
      for (const group of checklist.groups || []) {
        for (const question of group.questions || []) {
          allFileIds.push(...(question.executorImages?.map((img) => img.fileId) || []));
          allFileIds.push(...(question.reviewerImages?.map((img) => img.fileId) || []));
        }
        for (const section of group.sections || []) {
          for (const question of section.questions || []) {
            allFileIds.push(...(question.executorImages?.map((img) => img.fileId) || []));
            allFileIds.push(...(question.reviewerImages?.map((img) => img.fileId) || []));
          }
        }
      }
      for (const iteration of checklist.iterations || []) {
        for (const group of iteration.groups || []) {
          for (const question of group.questions || []) {
            allFileIds.push(...(question.executorImages?.map((img) => img.fileId) || []));
            allFileIds.push(...(question.reviewerImages?.map((img) => img.fileId) || []));
          }
          for (const section of group.sections || []) {
            for (const question of section.questions || []) {
              allFileIds.push(...(question.executorImages?.map((img) => img.fileId) || []));
              allFileIds.push(...(question.reviewerImages?.map((img) => img.fileId) || []));
            }
          }
        }
      }
    }

    const uniqueFileIds = [...new Set(allFileIds.filter((id) => id))];
    if (uniqueFileIds.length > 0) {
      await deleteImagesByFileIds(uniqueFileIds);
      deletionStats.imagesDeleted = uniqueFileIds.length;
    }
  } catch (imageError) {
    deletionStats.imagesDeleteError = imageError.message;
  }

  const deletedProjectChecklists = await ProjectChecklist.deleteMany({ projectId });
  deletionStats.projectChecklists = deletedProjectChecklists.deletedCount;

  const stages = await Stage.find({ project_id: projectId });
  const stageIds = stages.map((s) => s._id);
  deletionStats.stages = stages.length;

  const checklists = await Checklist.find({ stage_id: { $in: stageIds } });
  const checklistIds = checklists.map((c) => c._id);

  const deletedCheckpoints = await Checkpoint.deleteMany({ checklistId: { $in: checklistIds } });
  deletionStats.checkpoints = deletedCheckpoints.deletedCount;

  const deletedTransactions = await ChecklistTransaction.deleteMany({ checklist_id: { $in: checklistIds } });
  deletionStats.checklistTransactions = deletedTransactions.deletedCount;

  const deletedChecklists = await Checklist.deleteMany({ stage_id: { $in: stageIds } });
  deletionStats.checklists = deletedChecklists.deletedCount;

  const deletedStages = await Stage.deleteMany({ project_id: projectId });
  deletionStats.stagesDeleted = deletedStages.deletedCount;

  await Project.findByIdAndDelete(projectId);

  return deletionStats;
}
