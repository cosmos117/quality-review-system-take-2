import prisma from "../config/prisma.js";
import logger from "../utils/logger.js";
import { deleteImagesByFileIds } from "../local_storage.js";
import { ApiError } from "../utils/ApiError.js";
import { newId } from "../utils/newId.js";
import { calculateDefectCount, calculateCurrentMismatches, calculateIterationDefectRates } from "./defectUtility.service.js";

const parseJsonField = (field) => {
  if (!field) return [];
  if (typeof field === "string") return JSON.parse(field);
  return field;
};

export const allowedExecutorAnswers = ["Yes", "No", "NA", null];
export const allowedReviewerStatuses = ["Approved", "Rejected", null];

// Sanitize question data to fix any invalid values
export const sanitizeQuestion = (question) => {
  if (!question) return question;
  
  // Fix invalid executorAnswer
  if (question.executorAnswer && !allowedExecutorAnswers.includes(question.executorAnswer)) {
    question.executorAnswer = null;
  }
  
  // Fix invalid reviewerStatus
  if (question.reviewerStatus && !allowedReviewerStatuses.includes(question.reviewerStatus)) {
    question.reviewerStatus = null;
  }
  
  return question;
};

// Sanitize all groups recursively
export const sanitizeGroups = (groups) => {
  if (!Array.isArray(groups)) return groups;
  
  return groups.map((group) => {
    if (group.questions && Array.isArray(group.questions)) {
      group.questions = group.questions.map(sanitizeQuestion);
    }
    if (group.sections && Array.isArray(group.sections)) {
      group.sections = group.sections.map((section) => {
        if (section.questions && Array.isArray(section.questions)) {
          section.questions = section.questions.map(sanitizeQuestion);
        }
        return section;
      });
    }
    return group;
  });
};

export const updateProjectStatusToInProgress = async (projectId) => {
  const project = await prisma.project.findUnique({
    where: { id: projectId },
    select: { status: true },
  });

  if (project && project.status === "Not Started") {
    await prisma.project.update({
      where: { id: projectId },
      data: { status: "In Progress" },
    });
    // Invalidate project cache so the UI reflects the change
    import("../utils/cache.js")
      .then((cache) => {
        if (cache.invalidateProjects) cache.invalidateProjects();
      })
      .catch(() => {});
  }
};

export const inferStageKey = (stageName = "") => {
  const lower = stageName.toLowerCase();
  const match = lower.match(/(?:phase|stage)\s*(\d{1,2})/);
  if (match) {
    const phaseNum = parseInt(match[1]);
    return `stage${phaseNum}`;
  }
  return null;
};

export const mapTemplateToGroups = (stageTemplates = []) => {
  return stageTemplates.map((group) => ({
    groupName: (group?.text || "").trim(),
    defectCount: 0,
    questions: (group?.checkpoints || []).map((cp) => ({
      _id: cp._id || newId(),
      text: (cp?.text || "").trim(),
      executorAnswer: null,
      executorRemark: "",
      executorImages: [],
      reviewerAnswer: null,
      reviewerStatus: null,
      reviewerRemark: "",
      reviewerImages: [],
      categoryId: "",
      severity: "",
      answeredBy: { executor: null, reviewer: null },
      answeredAt: { executor: null, reviewer: null },
    })),
    sections: (group?.sections || []).map((sec) => ({
      _id: sec._id || newId(),
      sectionName: (sec?.text || "").trim(),
      questions: (sec?.checkpoints || []).map((cp) => ({
        _id: cp._id || newId(),
        text: (cp?.text || "").trim(),
        executorAnswer: null,
        executorRemark: "",
        executorImages: [],
        reviewerAnswer: null,
        reviewerStatus: null,
        reviewerRemark: "",
        reviewerImages: [],
        categoryId: "",
        severity: "",
        answeredBy: { executor: null, reviewer: null },
        answeredAt: { executor: null, reviewer: null },
      })),
    })),
  }));
};

export const ensureProjectChecklist = async ({ projectId, stageDoc }) => {
  const existing = await prisma.projectChecklist.findUnique({
    where: {
      projectId_stageId: { projectId, stageId: stageDoc._id || stageDoc.id },
    },
  });
  if (existing) return existing;

  const project = await prisma.project.findUnique({
    where: { id: projectId },
    select: { templateName: true },
  });

  if (!project) throw new ApiError(404, "Project not found");

  let template = null;
  if (project.templateName && project.templateName.trim()) {
    template = await prisma.template.findFirst({
      where: { templateName: project.templateName.trim(), isActive: true },
    });
  }

  if (!template) {
    template = await prisma.template.findFirst({
      where: { OR: [{ templateName: null }, { templateName: "" }] },
      orderBy: { createdAt: "asc" },
    });
  }

  if (!template) {
    template = await prisma.template.findFirst({
      orderBy: { createdAt: "asc" },
    });
  }

  if (!template)
    throw new ApiError(
      404,
      "Template not found. Please create a template first.",
    );

  const stageKey =
    stageDoc.stage_key || inferStageKey(stageDoc.stage_name) || "stage1";

  const stageData =
    typeof template.stageData === "string"
      ? JSON.parse(template.stageData)
      : template.stageData || {};

  const groups = mapTemplateToGroups(stageData[stageKey] || []);

  const created = await prisma.projectChecklist.create({
    data: {
      id: newId(),
      projectId,
      stageId: stageDoc._id || stageDoc.id,
      stage: stageDoc.stage_name,
      groups,
    },
  });

  return created;
};

const findQuestionInGroup = (group, questionId) => {
  const direct = (group.questions || []).find((q) => q._id === questionId);
  if (direct) {
    return { question: direct, section: null };
  }
  for (const section of group.sections || []) {
    const nested = (section.questions || []).find((q) => q._id === questionId);
    if (nested) {
      return { question: nested, section };
    }
  }
  return { question: null, section: null };
};

export const getProjectChecklist = async (projectId, stageId) => {
  const stageDoc = await prisma.stage.findUnique({
    where: { id: stageId, project_id: projectId },
    select: { id: true, stage_name: true, stage_key: true },
  });

  if (!stageDoc) throw new ApiError(404, "Stage not found for this project");

  const checklist = await ensureProjectChecklist({
    projectId,
    stageDoc: { ...stageDoc, _id: stageDoc.id },
  });

  const checklistObj = checklist.toJSON ? checklist.toJSON() : { ...checklist };
  let groups = parseJsonField(checklistObj.groups);
  
  // Sanitize current groups - fix any invalid data in the database
  groups = sanitizeGroups(groups);

  checklistObj.groups = groups.map((group) => {
    const currentDefects = calculateDefectCount(group);
    return { ...group, currentDefects };
  });

  let iterations = parseJsonField(checklistObj.iterations) || [];
  
  // Sanitize all iterations - fix any invalid data in the database
  iterations = iterations.map((iteration) => {
    if (iteration.groups) {
      iteration.groups = sanitizeGroups(iteration.groups);
    }
    return iteration;
  });
  
  logger.info(`[getProjectChecklist] Returning ${iterations.length} iterations for project ${projectId}, stage ${stageId}`);
  
  // Log each iteration to debug
  for (let i = 0; i < iterations.length; i++) {
    const iter = iterations[i];
    logger.info(`[getProjectChecklist]   Iteration ${i}: num=${iter?.iterationNumber}, groups=${Array.isArray(iter?.groups) ? iter.groups.length : 'N/A'}`);
  }
  if (iterations.length > 0) {
    logger.info(`[getProjectChecklist] First iteration structure: ${JSON.stringify(iterations[0]).substring(0, 300)}`);
  }

  return {
    ...checklistObj,
    iterations: iterations,
  };
};

export const updateExecutorAnswer = async (
  projectId,
  stageId,
  groupId,
  questionId,
  { answer, remark, images, categoryId, severity },
  userId,
) => {
  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId } },
  });

  if (!checklist) {
    throw new ApiError(404, "Checklist not found");
  }

  const groups = parseJsonField(checklist.groups);
  const group = groups.find(
    (g) => g._id === groupId || groups.indexOf(g).toString() === groupId,
  );

  if (!group) throw new ApiError(404, "Checklist group not found");

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) throw new ApiError(404, "Question not found in this group");

  let imagesToDelete = [];
  if (images !== undefined) {
    const newImages = Array.isArray(images) ? images : [];
    const oldImages = question.executorImages || [];
    imagesToDelete = oldImages.filter((oldImg) => !newImages.includes(oldImg));
  }

  if (answer !== undefined) {
    // Validate answer is in allowed list
    if (!allowedExecutorAnswers.includes(answer)) {
      throw new ApiError(400, `Invalid executorAnswer: ${answer}. Must be one of: Yes, No, NA, or null`);
    }
    question.executorAnswer = answer;
  }
  if (remark !== undefined) question.executorRemark = remark || "";
  if (images !== undefined)
    question.executorImages = Array.isArray(images) ? images : [];
  if (categoryId !== undefined) question.categoryId = categoryId || "";
  if (severity !== undefined) question.severity = severity || "";

  if (!question.answeredBy) question.answeredBy = {};
  if (!question.answeredAt) question.answeredAt = {};

  question.answeredBy.executor = userId;
  question.answeredAt.executor = new Date().toISOString();

  await prisma.projectChecklist.update({
    where: { id: checklist.id },
    data: { groups },
  });

  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (_) {}
  }

  // Trigger automated status transition
  await updateProjectStatusToInProgress(projectId);

  return group;
};

export const updateReviewerStatus = async (
  projectId,
  stageId,
  groupId,
  questionId,
  { answer, status, remark, images, categoryId, severity },
  userId,
) => {
  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId } },
  });

  if (!checklist) throw new ApiError(404, "Checklist not found");

  const groups = parseJsonField(checklist.groups);
  const group = groups.find(
    (g) => g._id === groupId || groups.indexOf(g).toString() === groupId,
  );

  if (!group) throw new ApiError(404, "Checklist group not found");

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) throw new ApiError(404, "Question not found in this group");

  let imagesToDelete = [];
  if (images !== undefined) {
    const newImages = Array.isArray(images) ? images : [];
    const oldImages = question.reviewerImages || [];
    imagesToDelete = oldImages.filter((oldImg) => !newImages.includes(oldImg));
  }

  if (answer !== undefined) question.reviewerAnswer = answer;
  if (status !== undefined) {
    // Validate status is in allowed list
    if (!allowedReviewerStatuses.includes(status)) {
      throw new ApiError(400, `Invalid reviewerStatus: ${status}. Must be one of: ${allowedReviewerStatuses.map(s => s === null ? 'null' : s).join(', ')}`);
    }
    question.reviewerStatus = status;
  }
  if (remark !== undefined) question.reviewerRemark = remark || "";
  if (images !== undefined)
    question.reviewerImages = Array.isArray(images) ? images : [];
  if (categoryId !== undefined) question.categoryId = categoryId || "";
  if (severity !== undefined) question.severity = severity || "";

  if (!question.answeredBy) question.answeredBy = {};
  if (!question.answeredAt) question.answeredAt = {};

  question.answeredBy.reviewer = userId;
  question.answeredAt.reviewer = new Date().toISOString();

  await prisma.projectChecklist.update({
    where: { id: checklist.id },
    data: { groups },
  });

  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (_) {}
  }

  // Trigger automated status transition
  await updateProjectStatusToInProgress(projectId);

  return group;
};

export const getChecklistIterations = async (projectId, stageId) => {
  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId } },
  });

  if (!checklist) {
    return { iterations: [], currentIteration: 1 };
  }

  const iterations = parseJsonField(checklist.iterations) || [];

  return {
    iterations,
    currentIteration: checklist.currentIteration || 1,
    totalIterations: iterations.length,
  };
};

export const getDefectRatesPerIteration = async (projectId, phaseNum) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true },
  });

  if (!stage) return { iterations: [], currentDefectRate: 0 };

  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } },
  });

  if (!checklist) return { iterations: [], currentDefectRate: 0 };

  let previousIterationDefects = 0;
  const iterationsWithRates = [];
  const iterations = parseJsonField(checklist.iterations) || [];
  const groups = parseJsonField(checklist.groups) || [];

  for (let i = 0; i < iterations.length; i++) {
    const iteration = iterations[i];
    let totalQuestions = 0;
    let cumulativeDefects = 0;

    (iteration.groups || []).forEach((group) => {
      cumulativeDefects += group.defectCount || 0;
      if (group.questions && Array.isArray(group.questions)) {
        totalQuestions += group.questions.length;
      }
      if (group.sections && Array.isArray(group.sections)) {
        group.sections.forEach((section) => {
          if (section.questions && Array.isArray(section.questions)) {
            totalQuestions += section.questions.length;
          }
        });
      }
    });

    const newDefectsInIteration = cumulativeDefects - previousIterationDefects;
    previousIterationDefects = cumulativeDefects;

    const defectRate =
      totalQuestions > 0
        ? parseFloat(
            ((newDefectsInIteration / totalQuestions) * 100).toFixed(2),
          )
        : 0;

    iterationsWithRates.push({
      iterationNumber: iteration.iterationNumber,
      revertedAt: iteration.revertedAt,
      revertNotes: iteration.revertNotes,
      totalQuestions,
      totalDefects: newDefectsInIteration,
      defectRate,
    });
  }

  const currentMismatchStats = calculateCurrentMismatches(groups);
  const currentDefectRate =
    currentMismatchStats.totalQuestions > 0
      ? parseFloat(
          (
            (currentMismatchStats.totalDefects /
              currentMismatchStats.totalQuestions) *
            100
          ).toFixed(2),
        )
      : 0;

  return {
    iterations: iterationsWithRates,
    current: {
      iterationNumber: checklist.currentIteration || 1,
      totalQuestions: currentMismatchStats.totalQuestions,
      totalDefects: currentMismatchStats.totalDefects,
      defectRate: currentDefectRate,
    },
  };
};

export const getOverallDefectRate = async (projectId) => {
  const stages = await prisma.stage.findMany({
    where: { project_id: projectId },
    select: { id: true, stage_key: true, stage_name: true },
  });

  if (!stages || stages.length === 0) {
    return {
      overallDefectRate: 0,
      totalQuestions: 0,
      totalDefects: 0,
      phaseBreakdown: [],
    };
  }

  const stageIds = stages.map((s) => s.id);
  const checklists = await prisma.projectChecklist.findMany({
    where: { projectId, stageId: { in: stageIds } },
  });

  const checklistMap = new Map(checklists.map((c) => [c.stageId, c]));

  let projectTotalQuestions = 0;
  let projectTotalDefects = 0;
  const phaseBreakdown = [];

  for (const stage of stages) {
    const checklist = checklistMap.get(stage.id);
    if (!checklist) continue;

    let stageTotalQuestions = 0;
    let stageTotalDefectsFound = 0;

    const groups = parseJsonField(checklist.groups) || [];

    // 1. Add current mismatches to total defects found in this phase
    const currentMismatches = calculateCurrentMismatches(groups);
    stageTotalDefectsFound += currentMismatches.totalDefects;
    stageTotalQuestions += currentMismatches.totalQuestions;

    // 2. Add historical defects from iterations
    const iterations = parseJsonField(checklist.iterations);
    const iterationStats = calculateIterationDefectRates(iterations, groups);

    const totalHistoricalDefectsInPhase = iterationStats.totalCumulativeDefects;

    stageTotalDefectsFound =
      totalHistoricalDefectsInPhase + currentMismatches.totalDefects;
    projectTotalDefects += stageTotalDefectsFound;

    // Use current questions count as the base for the phase
    const currentQuestionCount = currentMismatches.totalQuestions;

    phaseBreakdown.push({
      phase: stage.stage_key,
      stageName: stage.stage_name,
      currentTotalQuestions: currentQuestionCount,
      currentDefects: currentMismatches.totalDefects,
      historicalCumulativeDefects: totalHistoricalDefectsInPhase,
      totalDefectsFoundInPhase: stageTotalDefectsFound,
    });
  }

  // Calculate projectTotalQuestions as the sum of unique questions across all COMPLETED/ACTIVE stages
  projectTotalQuestions = phaseBreakdown.reduce(
    (acc, p) => acc + p.currentTotalQuestions,
    0,
  );

  let overallDefectRate =
    projectTotalQuestions > 0
      ? parseFloat(
          ((projectTotalDefects / projectTotalQuestions) * 100).toFixed(2),
        )
      : 0;

  // Cap at 100% just in case re-rejections blow it up
  if (overallDefectRate > 100) overallDefectRate = 100;

  await prisma.project.update({
    where: { id: projectId },
    data: { overallDefectRate },
  });

  return {
    overallDefectRate,
    totalQuestions: projectTotalQuestions,
    totalDefects: projectTotalDefects,
    phaseBreakdown,
  };
};
