import mongoose from "mongoose";
import ProjectChecklist from "../models/projectChecklist.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";
import Project from "../models/project.models.js";
import logger from "../utils/logger.js";
import { deleteImagesByFileIds } from "../gridfs.js";
import { ApiError } from "../utils/ApiError.js";

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
      sectionName: (sec?.text || "").trim(),
      questions: (sec?.checkpoints || []).map((cp) => ({
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
  const existing = await ProjectChecklist.findOne({
    projectId,
    stageId: stageDoc._id,
  });
  if (existing) return existing;

  const template = await Template.findOne().lean();
  if (!template) {
    throw new ApiError(
      404,
      "Template not found. Please create a template first.",
    );
  }

  const stageKey = inferStageKey(stageDoc.stage_name) || "stage1";
  const groups = mapTemplateToGroups(template[stageKey] || []);

  const created = await ProjectChecklist.create({
    projectId,
    stageId: stageDoc._id,
    stage: stageDoc.stage_name,
    groups,
  });
  return created;
};

const findQuestionInGroup = (group, questionId) => {
  const direct = group.questions.id(questionId);
  if (direct) {
    return { question: direct, section: null };
  }
  for (const section of group.sections) {
    const nested = section.questions.id(questionId);
    if (nested) {
      return { question: nested, section };
    }
  }
  return { question: null, section: null };
};

const calculateDefectCount = (group) => {
  let defectCount = 0;
  for (const question of group.questions) {
    if (
      question.executorAnswer &&
      question.reviewerAnswer &&
      question.executorAnswer !== question.reviewerAnswer
    ) {
      defectCount++;
    }
  }
  for (const section of group.sections) {
    for (const question of section.questions) {
      if (
        question.executorAnswer &&
        question.reviewerAnswer &&
        question.executorAnswer !== question.reviewerAnswer
      ) {
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
        if (
          exAns !== null &&
          exAns !== undefined &&
          revAns !== null &&
          revAns !== undefined &&
          exAns !== revAns
        ) {
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
            if (
              exAns !== null &&
              exAns !== undefined &&
              revAns !== null &&
              revAns !== undefined &&
              exAns !== revAns
            ) {
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

  for (let i = 0; i < checklist.iterations.length; i++) {
    const iteration = checklist.iterations[i];
    let totalQuestions = 0;
    let cumulativeDefects = 0;

    iteration.groups.forEach((group) => {
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

    iterationRates.push(defectRate > 100 ? 100 : defectRate);
  }

  return iterationRates;
};

export const getProjectChecklist = async (projectId, stageId) => {
  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId }).select("_id stage_name").lean();
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const checklistObj = checklist.toObject();
  checklistObj.groups = checklistObj.groups.map((group) => {
    const currentDefects = calculateDefectCount(group);
    return { ...group, currentDefects };
  });

  return checklistObj;
};

export const updateExecutorAnswer = async (
  projectId,
  stageId,
  groupId,
  questionId,
  { answer, remark, images, categoryId, severity },
  userId,
) => {
  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId }).select("_id stage_name").lean();
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const group = checklist.groups.id(groupId);
  if (!group) {
    throw new ApiError(404, "Checklist group not found");
  }

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) {
    throw new ApiError(404, "Question not found in this group");
  }

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

  question.answeredBy.executor = userId;
  question.answeredAt.executor = new Date();

  await checklist.save();

  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (_) {
      // Don't fail the request if image deletion fails
    }
  }

  return group.toObject();
};

export const updateReviewerStatus = async (
  projectId,
  stageId,
  groupId,
  questionId,
  { answer, status, remark, images, categoryId, severity },
  userId,
) => {
  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId }).select("_id stage_name").lean();
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const group = checklist.groups.id(groupId);
  if (!group) {
    throw new ApiError(404, "Checklist group not found");
  }

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) {
    throw new ApiError(404, "Question not found in this group");
  }

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

  question.answeredBy.reviewer = userId;
  question.answeredAt.reviewer = new Date();

  await checklist.save();

  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (_) {
      // Don't fail the request if image deletion fails
    }
  }

  return group.toObject();
};

export const getChecklistIterations = async (projectId, stageId) => {
  const checklist = await ProjectChecklist.findOne({
    projectId,
    stageId,
  }).populate("iterations.revertedBy", "name email").lean();

  if (!checklist) {
    return { iterations: [], currentIteration: 1 };
  }

  return {
    iterations: checklist.iterations,
    currentIteration: checklist.currentIteration,
    totalIterations: checklist.iterations.length,
  };
};

export const getDefectRatesPerIteration = async (projectId, phaseNum) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  }).select("_id").lean();

  if (!stage) {
    return { iterations: [], currentDefectRate: 0 };
  }

  const checklist = await ProjectChecklist.findOne({
    projectId,
    stageId: stage._id,
  }).lean();

  if (!checklist) {
    return { iterations: [], currentDefectRate: 0 };
  }

  let previousIterationDefects = 0;
  const iterationsWithRates = [];

  for (let i = 0; i < checklist.iterations.length; i++) {
    const iteration = checklist.iterations[i];
    let totalQuestions = 0;
    let cumulativeDefects = 0;

    iteration.groups.forEach((group) => {
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

  const currentMismatchStats = calculateCurrentMismatches(checklist.groups);
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
  const stages = await Stage.find({ project_id: projectId }).select("_id stage_key stage_name").lean();

  if (!stages || stages.length === 0) {
    return {
      overallDefectRate: 0,
      totalQuestions: 0,
      totalDefects: 0,
      phaseBreakdown: [],
    };
  }

  const stageIds = stages.map((s) => s._id);
  const checklists = await ProjectChecklist.find({ projectId, stageId: { $in: stageIds } }).lean();
  const checklistMap = new Map(checklists.map((c) => [c.stageId.toString(), c]));

  let grandTotalQuestions = 0;
  let grandTotalDefects = 0;
  const phaseBreakdown = [];
  let sumOfAllIterationDefectRates = 0;
  let totalIterationsAcrossAllPhases = 0;
  const numberOfPhases = stages.length;

  for (const stage of stages) {
    const checklist = checklistMap.get(stage._id.toString());

    if (checklist) {
      let totalQuestionsInPhase = 0;
      checklist.groups.forEach((group) => {
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

      const currentMismatches = calculateCurrentMismatches(checklist.groups);
      const totalDefectsInPhase = currentMismatches.totalDefects;

      grandTotalQuestions += totalQuestionsInPhase;
      grandTotalDefects += totalDefectsInPhase;

      const phaseDefectRate =
        totalQuestionsInPhase > 0
          ? parseFloat(
              ((totalDefectsInPhase / totalQuestionsInPhase) * 100).toFixed(2),
            )
          : 0;

      const cappedPhaseDefectRate =
        phaseDefectRate > 100 ? 100 : phaseDefectRate;

      phaseBreakdown.push({
        phase: stage.stage_key,
        stageName: stage.stage_name,
        totalQuestions: totalQuestionsInPhase,
        totalDefects: totalDefectsInPhase,
        defectRate: cappedPhaseDefectRate,
      });

      const iterationRates = calculateIterationDefectRates(checklist);

      logger.info(
        `Phase ${stage.stage_key}: currentIteration=${checklist.currentIteration || 1}, Past iterations count: ${checklist.iterations.length}, Past iteration rates: ${JSON.stringify(iterationRates)}, Current defect rate: ${cappedPhaseDefectRate}%`,
      );

      iterationRates.forEach((rate) => {
        sumOfAllIterationDefectRates += rate;
        totalIterationsAcrossAllPhases += 1;
      });

      logger.info(
        `After phase ${stage.stage_key}: Sum = ${sumOfAllIterationDefectRates}, Total iterations = ${totalIterationsAcrossAllPhases}`,
      );
    }
  }

  let overallDefectRate = parseFloat(sumOfAllIterationDefectRates.toFixed(2));

  await Project.findByIdAndUpdate(
    projectId,
    { overallDefectRate },
    { new: true },
  );

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
