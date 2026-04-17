import prisma from "../config/prisma.js";
import { deleteImagesByFileIds } from "../local_storage.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";
import { ApiError } from "../utils/ApiError.js";
import { getOrSet, keys, TTL, invalidateProjects, invalidateStages } from "../utils/cache.js";
import { clearAnalyticsCache } from "./analytics-excel.service.js";
import { newId } from "../utils/newId.js";

// Helpers 

async function resolveTemplateForProject(projectOrTemplateName) {
  const templateName = typeof projectOrTemplateName === "string" 
    ? projectOrTemplateName 
    : projectOrTemplateName?.templateName;

  if (templateName && templateName.trim()) {
    const named = await prisma.template.findFirst({
      where: { 
        templateName: templateName.trim(),
        isActive: true 
      }
    });
    if (!named) throw new ApiError(404, `Template "${templateName}" not found`);
    return named;
  }

  const legacy = await prisma.template.findFirst({
    where: {
      OR: [
        { templateName: null },
        { templateName: "" }
      ]
    },
    orderBy: { createdAt: 'asc' }
  });

  if (legacy) return legacy;

  const anyTemplate = await prisma.template.findFirst({
    orderBy: { createdAt: 'asc' }
  });
  
  if (!anyTemplate) {
    throw new ApiError(404, "Template not found. Please create a template first.");
  }
  return anyTemplate;
}

// Ensure parsing of template json 
const parseJsonField = (field) => {
    if (!field) return {};
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

const INACTIVE_STATUSES = ["pending", "Not Started"];
const ACTIVE_STATUSES = ["in_progress", "In Progress"];

const isInactiveStatus = (s) => INACTIVE_STATUSES.includes(s);
const isActiveStatus = (s) => ACTIVE_STATUSES.includes(s);
const isCompletedStatus = (s) => s === "completed" || s === "Completed";

async function syncCheckpointsWithTemplate(projectId) {
  try {
    const project = await prisma.project.findUnique({
      where: { id: projectId },
      select: { templateName: true }
    });
    if (!project) return;

    const template = await resolveTemplateForProject(project);
    const templateStageData = parseJsonField(template.stageData);

    const stages = await prisma.stage.findMany({
      where: { project_id: projectId },
      select: { id: true, stage_name: true, stage_key: true }
    });

    const deriveStageKeyFromName = (stageName) => {
      const match = stageName.toLowerCase().match(/(?:phase|stage)\s*(\d{1,2})/);
      return match ? `stage${parseInt(match[1])}` : null;
    };

    const checkpointsToUpdate = [];

    for (const stage of stages) {
      const templateStageKey = stage.stage_key || deriveStageKeyFromName(stage.stage_name);
      if (!templateStageKey) continue;

      const templateChecklists = templateStageData[templateStageKey] || [];
      const checklists = await prisma.checklist.findMany({
        where: { stage_id: stage.id },
        select: { id: true, checklist_name: true }
      });

      for (const checklist of checklists) {
        const templateChecklist = templateChecklists.find(tc => tc.text === checklist.checklist_name);
        if (!templateChecklist) continue;

        const checkpoints = await prisma.checkpoint.findMany({
          where: { checklistId: checklist.id }
        });

        for (const checkpoint of checkpoints) {
          const templateCheckpoint = templateChecklist.checkpoints?.find(tcp => tcp.text === checkpoint.question);
          if (templateCheckpoint?.categoryId) {
            checkpointsToUpdate.push({
              id: checkpoint.id,
              categoryId: templateCheckpoint.categoryId
            });
          }
        }
      }
    }

    if (checkpointsToUpdate.length > 0) {
      // Prisma does not have a native bulkWrite for updates with different values, 
      // so we use a transaction of updates
      await prisma.$transaction(
        checkpointsToUpdate.map(update => 
          prisma.checkpoint.update({
            where: { id: update.id },
            data: { categoryId: update.categoryId }
          })
        )
      );
    }
  } catch (error) {
    // Silent failure
  }
}

async function createStagesAndChecklistsFromTemplate(projectId, templateName) {
  try {
    const template = await resolveTemplateForProject(templateName);
    const stageData = parseJsonField(template.stageData);
    const stageNames = parseJsonField(template.stageNames);

    const stageKeys = Object.keys(stageData)
      .filter((key) => /^stage\d{1,2}$/.test(key))
      .sort((a, b) => parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")));

    for (const stageKey of stageKeys) {
      const stageNum = parseInt(stageKey.replace("stage", ""));
      const stageName = stageNames[stageKey] || `Phase ${stageNum}`;

      const stage = await prisma.stage.create({
        data: {
          id: newId(),
          project_id: projectId,
          stage_name: stageName,
          stage_key: stageKey,
          status: "pending"
        }
      });

      const templateGroups = stageData[stageKey] || [];
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

      await prisma.projectChecklist.create({
        data: {
          id: newId(),
          projectId,
          stageId: stage.id,
          stage: stageKey,
          groups
        }
      });
    }
  } catch (error) {
    // Silent failure
  }
}

// Service functions 

export async function getAllProjects(query) {
  const { page, limit, skip } = parsePagination(query);
  const queryStr = `p${page}_l${limit}`;

  return getOrSet(
    keys.allProjects(queryStr),
    async () => {
      const total = await prisma.project.count();

      const projects = await prisma.project.findMany({
        include: {
          creator: { select: { name: true, email: true } }
        },
        orderBy: { createdAt: "desc" },
        ...(limit ? { skip, take: limit } : {})
      });

      // Format `created_by` back for legacy compatibility
      const formattedProjects = projects.map(p => ({
        ...p,
        created_by: p.creator
      }));

      return paginatedResponse(formattedProjects, total, { page, limit });
    },
    TTL.PROJECTS
  );
}

export async function getProjectsForUser(userId) {
  const memberships = await prisma.projectMembership.findMany({
    where: { user_id: userId },
    include: {
      project: {
        include: {
          creator: { select: { name: true, email: true } }
        }
      },
      role: { select: { role_name: true } }
    }
  });

  const validMemberships = memberships.filter(m => m.project != null);
  const projectIds = validMemberships.map(m => m.project_id);

  const allMemberships = await prisma.projectMembership.findMany({
    where: { project_id: { in: projectIds } },
    select: { project_id: true, user_id: true }
  });

  const projectMembersMap = {};
  for (const m of allMemberships) {
    if (!projectMembersMap[m.project_id]) projectMembersMap[m.project_id] = [];
    projectMembersMap[m.project_id].push(m.user_id);
  }

  return validMemberships.map((m) => {
    const project = m.project;
    const formattedProject = {
      ...project,
      created_by: project.creator
    };
    
    return {
      ...formattedProject,
      userRole: m.role?.role_name || null,
      membershipId: m.id,
      assignedEmployees: projectMembersMap[project.id] || [],
    };
  });
}

export async function getProjectById(id) {
  return getOrSet(
    keys.projectById(id),
    async () => {
      const project = await prisma.project.findUnique({
        where: { id },
        include: { creator: { select: { name: true, email: true } } }
      });
      if (!project) throw new ApiError(404, "Project not found");
      return { ...project, created_by: project.creator };
    },
    TTL.PROJECT_BY_ID
  );
}
export async function createProject(data) {
  const projectData = {
    ...data,
    id: newId()
  };

  if (projectData.start_date) {
    projectData.start_date = new Date(projectData.start_date);
  }
  if (projectData.end_date) {
    projectData.end_date = new Date(projectData.end_date);
  }

  const project = await prisma.project.create({
    data: projectData,
    include: { creator: { select: { name: true, email: true } } }
  });

  // Automatically initialize stages if template is assigned and project is active
  if (project.templateName && (isActiveStatus(project.status) || isCompletedStatus(project.status))) {
    await createStagesAndChecklistsFromTemplate(project.id, project.templateName);
  }

  invalidateProjects();
  return { ...project, created_by: project.creator };
}

export async function updateProject(projectId, data, requestingUserId) {
  const existing = await prisma.project.findUnique({ where: { id: projectId } });
  if (!existing) throw new ApiError(404, "Project not found");

  const prevStatus = existing.status;
  const requestedStatus = typeof data.status === "string" ? data.status : existing.status;

  if (isInactiveStatus(prevStatus) && isActiveStatus(requestedStatus)) {
    const assigned = await prisma.projectMembership.findFirst({
      where: { project_id: projectId, user_id: requestingUserId }
    });
    // For legacy reasons, we might allow bypassing this if the user is an admin or creator
    // but the rule is generally for assigned users to start.
    if (!assigned && existing.created_by !== requestingUserId) {
       // Check if user is admin as well? For now, keep as is but supporting new statuses
       // throw new ApiError(403, "Only assigned users can start this project");
    }
  }

  const updateData = {};
  if (data.project_no !== undefined) updateData.project_no = data.project_no;
  if (data.internal_order_no !== undefined) updateData.internal_order_no = data.internal_order_no;
  if (typeof data.project_name === "string") updateData.project_name = data.project_name;
  if (typeof data.description === "string") updateData.description = data.description;
  if (typeof data.status === "string") updateData.status = data.status;
  if (typeof data.priority === "string") updateData.priority = data.priority;
  if (data.start_date) updateData.start_date = new Date(data.start_date);
  if (data.end_date) updateData.end_date = new Date(data.end_date);
  if (data.isReviewApplicable !== undefined) updateData.isReviewApplicable = data.isReviewApplicable;
  if (data.reviewApplicableRemark !== undefined) updateData.reviewApplicableRemark = data.reviewApplicableRemark;
  
  if (data.templateName !== undefined) {
    if (data.templateName && data.templateName.trim()) {
      await resolveTemplateForProject(data.templateName.trim());
      updateData.templateName = data.templateName.trim();
    } else {
      updateData.templateName = null;
    }
  }

  const updatedProject = await prisma.project.update({
    where: { id: projectId },
    data: updateData,
    include: { creator: { select: { name: true, email: true } } }
  });

  invalidateProjects();

  // Initialize stages if:
  // 1. Transitioning to active/completed from inactive
  // 2. OR if template changed and project is already active
  // 3. AND no stages currently exist
  const statusChangedToActive = isInactiveStatus(prevStatus) && (isActiveStatus(updatedProject.status) || isCompletedStatus(updatedProject.status));
  const templateChanged = data.templateName !== undefined && data.templateName !== existing.templateName;
  
  if (statusChangedToActive || (templateChanged && isActiveStatus(updatedProject.status))) {
    const existingStagesCount = await prisma.stage.count({ where: { project_id: projectId } });
    if (existingStagesCount === 0 && updatedProject.templateName) {
      await createStagesAndChecklistsFromTemplate(projectId, updatedProject.templateName);
      invalidateStages(projectId);
    }
  }

  return { ...updatedProject, created_by: updatedProject.creator };
}

export async function syncProjectCheckpointCategories(projectId) {
  await syncCheckpointsWithTemplate(projectId);
}

export async function getProjectStages(projectId) {
  return getOrSet(
    keys.projectStages(projectId),
    async () => {
      const stages = await prisma.stage.findMany({
        where: { project_id: projectId },
        orderBy: { createdAt: "asc" }
      });
      return stages.map(stage => ({
        _id: stage.id,
        stage_name: stage.stage_name,
        stage_key: stage.stage_key,
        status: stage.status,
        loopback_count: stage.loopback_count || 0,
        conflict_count: stage.conflict_count || 0,
      }));
    },
    TTL.PROJECT_STAGES
  );
}

export async function deleteProject(projectId) {
  const project = await prisma.project.findUnique({
    where: { id: projectId },
    select: { id: true }
  });
  if (!project) throw new ApiError(404, "Project not found");

  const deletionStats = {};

  // Find IDs for nested deletion
  const projectChecklists = await prisma.projectChecklist.findMany({
    where: { projectId }
  });
  const stages = await prisma.stage.findMany({
    where: { project_id: projectId },
    select: { id: true }
  });
  const stageIds = stages.map(s => s.id);

  const checklists = await prisma.checklist.findMany({
    where: { stage_id: { in: stageIds } },
    select: { id: true }
  });
  const checklistIds = checklists.map(c => c.id);

  // Collect images to delete from GridFS/Local Storage
  try {
    const allFileIds = [];
    
    for (const checklist of projectChecklists) {
      const groups = parseJsonField(checklist.groups) || [];
      const iterations = parseJsonField(checklist.iterations) || [];

      // Collect from groups
      for (const group of groups) {
        for (const question of group.questions || []) {
          if (question.executorImages) allFileIds.push(...question.executorImages.map(img => img.fileId));
          if (question.reviewerImages) allFileIds.push(...question.reviewerImages.map(img => img.fileId));
        }
        for (const section of group.sections || []) {
          for (const question of section.questions || []) {
            if (question.executorImages) allFileIds.push(...question.executorImages.map(img => img.fileId));
            if (question.reviewerImages) allFileIds.push(...question.reviewerImages.map(img => img.fileId));
          }
        }
      }

      // Collect from iterations
      for (const iteration of iterations) {
        for (const group of iteration.groups || []) {
          for (const question of group.questions || []) {
            if (question.executorImages) allFileIds.push(...question.executorImages.map(img => img.fileId));
            if (question.reviewerImages) allFileIds.push(...question.reviewerImages.map(img => img.fileId));
          }
          for (const section of group.sections || []) {
            for (const question of section.questions || []) {
              if (question.executorImages) allFileIds.push(...question.executorImages.map(img => img.fileId));
              if (question.reviewerImages) allFileIds.push(...question.reviewerImages.map(img => img.fileId));
            }
          }
        }
      }
    }

    const uniqueFileIds = [...new Set(allFileIds.filter(id => id))];
    if (uniqueFileIds.length > 0) {
      await deleteImagesByFileIds(uniqueFileIds);
      deletionStats.imagesDeleted = uniqueFileIds.length;
    }
  } catch (imageError) {
    deletionStats.imagesDeleteError = imageError.message;
  }

  // Delete records from database using Prisma Transaction to ensure data integrity
  const [
    deletedMemberships,
    deletedAnswers,
    deletedApprovals,
    deletedProjectChecklists,
    deletedCheckpoints,
    deletedTransactions,
    deletedChecklists,
    deletedStages,
    deletedProject
  ] = await prisma.$transaction([
    prisma.projectMembership.deleteMany({ where: { project_id: projectId } }),
    prisma.checklistAnswer.deleteMany({ where: { project_id: projectId } }),
    prisma.checklistApproval.deleteMany({ where: { project_id: projectId } }),
    prisma.projectChecklist.deleteMany({ where: { projectId } }),
    prisma.checkpoint.deleteMany({ where: { checklistId: { in: checklistIds.length > 0 ? checklistIds : [''] } } }),
    prisma.checklistTransaction.deleteMany({ where: { checklist_id: { in: checklistIds.length > 0 ? checklistIds : [''] } } }),
    prisma.checklist.deleteMany({ where: { stage_id: { in: stageIds.length > 0 ? stageIds : [''] } } }),
    prisma.stage.deleteMany({ where: { project_id: projectId } }),
    prisma.project.delete({ where: { id: projectId } })
  ]);

  deletionStats.memberships = deletedMemberships.count;
  deletionStats.checklistAnswers = deletedAnswers.count;
  deletionStats.checklistApprovals = deletedApprovals.count;
  deletionStats.projectChecklists = deletedProjectChecklists.count;
  deletionStats.checkpoints = deletedCheckpoints.count;
  deletionStats.checklistTransactions = deletedTransactions.count;
  deletionStats.checklists = deletedChecklists.count;
  deletionStats.stagesDeleted = deletedStages.count;

  invalidateProjects();
  invalidateStages(projectId);
  clearAnalyticsCache();

  return deletionStats;
}
