import prisma from "../config/prisma.js";
import logger from "../utils/logger.js";
import { deleteImagesByFileIds } from "../local_storage.js";
import { ApiError } from "../utils/ApiError.js";
import { newId } from "../utils/newId.js";

const parseJsonField = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

export const allowedExecutorAnswers = ["Yes", "No", "NA", null];
export const allowedReviewerStatuses = ["Approved", "Rejected", null];

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
    where: { projectId_stageId: { projectId, stageId: stageDoc._id || stageDoc.id } }
  });
  if (existing) return existing;

  const project = await prisma.project.findUnique({
    where: { id: projectId },
    select: { templateName: true }
  });

  if (!project) throw new ApiError(404, "Project not found");

  let template = null;
  if (project.templateName && project.templateName.trim()) {
    template = await prisma.template.findFirst({
      where: { templateName: project.templateName.trim(), isActive: true }
    });
  }

  if (!template) {
    template = await prisma.template.findFirst({
      where: { OR: [{ templateName: null }, { templateName: "" }] },
      orderBy: { createdAt: "asc" }
    });
  }

  if (!template) {
    template = await prisma.template.findFirst({
      orderBy: { createdAt: "asc" }
    });
  }

  if (!template) throw new ApiError(404, "Template not found. Please create a template first.");

  const stageKey = stageDoc.stage_key || inferStageKey(stageDoc.stage_name) || "stage1";
  
  const stageData = typeof template.stageData === 'string' 
    ? JSON.parse(template.stageData) 
    : (template.stageData || {});
    
  const groups = mapTemplateToGroups(stageData[stageKey] || []);

  const created = await prisma.projectChecklist.create({
    data: {
      id: newId(),
      projectId,
      stageId: stageDoc._id || stageDoc.id,
      stage: stageDoc.stage_name,
      groups
    }
  });

  return created;
};

const findQuestionInGroup = (group, questionId) => {
  const direct = (group.questions || []).find(q => q._id === questionId);
  if (direct) {
    return { question: direct, section: null };
  }
  for (const section of group.sections || []) {
    const nested = (section.questions || []).find(q => q._id === questionId);
    if (nested) {
      return { question: nested, section };
    }
  }
  return { question: null, section: null };
};

const calculateDefectCount = (group) => {
  let defectCount = 0;
  for (const question of group.questions || []) {
    if (question.executorAnswer && question.reviewerAnswer && question.executorAnswer !== question.reviewerAnswer) {
      defectCount++;
    }
  }
  for (const section of group.sections || []) {
    for (const question of section.questions || []) {
      if (question.executorAnswer && question.reviewerAnswer && question.executorAnswer !== question.reviewerAnswer) {
        defectCount++;
      }
    }
  }
  return defectCount;
};

const calculateCurrentMismatches = (groups) => {
  let totalQuestions = 0;
  let totalDefects = 0;

  groups.forEach((group) => {
    if (group.questions && Array.isArray(group.questions)) {
      group.questions.forEach((q) => {
        totalQuestions++;
        const exAns = q.executorAnswer;
        const revAns = q.reviewerAnswer;
        if (exAns !== null && exAns !== undefined && revAns !== null && revAns !== undefined && exAns !== revAns) {
          totalDefects++;
        }
      });
    }
    if (group.sections && Array.isArray(group.sections)) {
      group.sections.forEach((section) => {
        if (section.questions && Array.isArray(section.questions)) {
          section.questions.forEach((q) => {
            totalQuestions++;
            const exAns = q.executorAnswer;
            const revAns = q.reviewerAnswer;
            if (exAns !== null && exAns !== undefined && revAns !== null && revAns !== undefined && exAns !== revAns) {
              totalDefects++;
            }
          });
        }
      });
    }
  });

  return { totalQuestions, totalDefects };
};

const calculateIterationDefectRates = (checklist) => {
  const iterationRates = [];
  let previousIterationDefects = 0;
  
  const iterations = parseJsonField(checklist.iterations) || [];

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
        ? parseFloat(((newDefectsInIteration / totalQuestions) * 100).toFixed(2))
        : 0;

    iterationRates.push(defectRate > 100 ? 100 : defectRate);
  }

  return iterationRates;
};

export const getProjectChecklist = async (projectId, stageId) => {
  const stageDoc = await prisma.stage.findUnique({
    where: { id: stageId, project_id: projectId },
    select: { id: true, stage_name: true, stage_key: true }
  });

  if (!stageDoc) throw new ApiError(404, "Stage not found for this project");

  const checklist = await ensureProjectChecklist({ projectId, stageDoc: { ...stageDoc, _id: stageDoc.id } });

  const checklistObj = { ...checklist };
  const groups = parseJsonField(checklistObj.groups);
  
  checklistObj.groups = groups.map((group) => {
    const currentDefects = calculateDefectCount(group);
    return { ...group, currentDefects };
  });
  
  checklistObj.iterations = parseJsonField(checklistObj.iterations) || [];

  return checklistObj;
};

export const updateExecutorAnswer = async (projectId, stageId, groupId, questionId, { answer, remark, images, categoryId, severity }, userId) => {
  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId } }
  });

  if (!checklist) {
    throw new ApiError(404, "Checklist not found");
  }

  const groups = parseJsonField(checklist.groups);
  const group = groups.find(g => g._id === groupId || groups.indexOf(g).toString() === groupId);

  if (!group) throw new ApiError(404, "Checklist group not found");

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) throw new ApiError(404, "Question not found in this group");

  let imagesToDelete = [];
  if (images !== undefined) {
    const newImages = Array.isArray(images) ? images : [];
    const oldImages = question.executorImages || [];
    imagesToDelete = oldImages.filter((oldImg) => !newImages.includes(oldImg));
  }

  if (answer !== undefined) question.executorAnswer = answer;
  if (remark !== undefined) question.executorRemark = remark || "";
  if (images !== undefined) question.executorImages = Array.isArray(images) ? images : [];
  if (categoryId !== undefined) question.categoryId = categoryId || "";
  if (severity !== undefined) question.severity = severity || "";

  if(!question.answeredBy) question.answeredBy = {};
  if(!question.answeredAt) question.answeredAt = {};

  question.answeredBy.executor = userId;
  question.answeredAt.executor = new Date().toISOString();

  await prisma.projectChecklist.update({
    where: { id: checklist.id },
    data: { groups }
  });

  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (_) {}
  }

  return group;
};

export const updateReviewerStatus = async (projectId, stageId, groupId, questionId, { answer, status, remark, images, categoryId, severity }, userId) => {
  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId } }
  });

  if (!checklist) throw new ApiError(404, "Checklist not found");

  const groups = parseJsonField(checklist.groups);
  const group = groups.find(g => g._id === groupId || groups.indexOf(g).toString() === groupId);

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
  if (status !== undefined) question.reviewerStatus = status;
  if (remark !== undefined) question.reviewerRemark = remark || "";
  if (images !== undefined) question.reviewerImages = Array.isArray(images) ? images : [];
  if (categoryId !== undefined) question.categoryId = categoryId || "";
  if (severity !== undefined) question.severity = severity || "";

  if(!question.answeredBy) question.answeredBy = {};
  if(!question.answeredAt) question.answeredAt = {};
  
  question.answeredBy.reviewer = userId;
  question.answeredAt.reviewer = new Date().toISOString();

  await prisma.projectChecklist.update({
    where: { id: checklist.id },
    data: { groups }
  });

  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (_) {}
  }

  return group;
};

export const getChecklistIterations = async (projectId, stageId) => {
  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId } }
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
    select: { id: true }
  });

  if (!stage) return { iterations: [], currentDefectRate: 0 };

  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } }
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

    const defectRate = totalQuestions > 0
      ? parseFloat(((newDefectsInIteration / totalQuestions) * 100).toFixed(2))
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
  const currentDefectRate = currentMismatchStats.totalQuestions > 0
    ? parseFloat(((currentMismatchStats.totalDefects / currentMismatchStats.totalQuestions) * 100).toFixed(2))
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
    select: { id: true, stage_key: true, stage_name: true }
  });

  if (!stages || stages.length === 0) {
    return { overallDefectRate: 0, totalQuestions: 0, totalDefects: 0, phaseBreakdown: [] };
  }

  const stageIds = stages.map((s) => s.id);
  const checklists = await prisma.projectChecklist.findMany({
    where: { projectId, stageId: { in: stageIds } }
  });

  const checklistMap = new Map(checklists.map((c) => [c.stageId, c]));

  let grandTotalQuestions = 0;
  let grandTotalDefects = 0;
  const phaseBreakdown = [];
  let sumOfAllIterationDefectRates = 0;
  let totalIterationsAcrossAllPhases = 0;
  const numberOfPhases = stages.length;

  for (const stage of stages) {
    const checklist = checklistMap.get(stage.id);

    if (checklist) {
      let totalQuestionsInPhase = 0;
      const groups = parseJsonField(checklist.groups) || [];

      groups.forEach((group) => {
        if (group.questions && Array.isArray(group.questions)) {
          totalQuestionsInPhase += group.questions.length;
        }
        if (group.sections && Array.isArray(group.sections)) {
          group.sections.forEach((section) => {
            if (section.questions && Array.isArray(section.questions)) {
              totalQuestionsInPhase += section.questions.length;
            }
          });
        }
      });

      const currentMismatches = calculateCurrentMismatches(groups);
      const totalDefectsInPhase = currentMismatches.totalDefects;

      grandTotalQuestions += totalQuestionsInPhase;
      grandTotalDefects += totalDefectsInPhase;

      const phaseDefectRate = totalQuestionsInPhase > 0
        ? parseFloat(((totalDefectsInPhase / totalQuestionsInPhase) * 100).toFixed(2))
        : 0;

      const cappedPhaseDefectRate = phaseDefectRate > 100 ? 100 : phaseDefectRate;

      phaseBreakdown.push({
        phase: stage.stage_key,
        stageName: stage.stage_name,
        totalQuestions: totalQuestionsInPhase,
        totalDefects: totalDefectsInPhase,
        defectRate: cappedPhaseDefectRate,
      });

      const iterationRates = calculateIterationDefectRates(checklist);

      iterationRates.forEach((rate) => {
        sumOfAllIterationDefectRates += rate;
        totalIterationsAcrossAllPhases += 1;
      });
    }
  }

  let overallDefectRate = parseFloat(sumOfAllIterationDefectRates.toFixed(2));

  await prisma.project.update({
    where: { id: projectId },
    data: { overallDefectRate }
  });

  return {
    overallDefectRate,
    totalQuestions: grandTotalQuestions,
    totalDefects: grandTotalDefects,
    phaseBreakdown,
    calculationDetails: {
      sumOfAllIterationDefectRates,
      totalIterationsAcrossAllPhases,
      numberOfPhases,
    },
  };
};
