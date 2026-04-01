import prisma from "../config/prisma.js";
import { ensureProjectChecklist } from "./projectChecklist.service.js";
import { ApiError } from "../utils/ApiError.js";
import logger from "../utils/logger.js";
import { newId } from "../utils/newId.js";

const parseJsonField = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

const calculateCurrentMismatches = (group) => {
  let mismatchCount = 0;
  for (const question of group.questions || []) {
    if (
      question.executorAnswer &&
      question.reviewerAnswer &&
      question.executorAnswer !== question.reviewerAnswer
    ) {
      mismatchCount++;
    }
  }
  for (const section of group.sections || []) {
    for (const question of section.questions || []) {
      if (
        question.executorAnswer &&
        question.reviewerAnswer &&
        question.executorAnswer !== question.reviewerAnswer
      ) {
        mismatchCount++;
      }
    }
  }
  return mismatchCount;
};

export const accumulateDefectsForChecklistGroups = (groups) => {
  let totalNewDefects = 0;
  for (const group of groups) {
    const currentMismatches = calculateCurrentMismatches(group);
    const existingDefectCount = group.defectCount || 0;
    group.defectCount = existingDefectCount + currentMismatches;
    totalNewDefects += currentMismatches;
  }
  return totalNewDefects;
};

export const getChecklistAnswers = async (projectId, phaseNum, normalizedRole) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true, stage_name: true },
  });

  if (!stage) return {};

  let checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } }
  });

  if (!checklist) {
    try {
      checklist = await ensureProjectChecklist({ projectId, stageDoc: { _id: stage.id, stage_name: stage.stage_name, stage_key: stageKey } });
    } catch (_) {
      return {};
    }
  }

  const answerMap = {};
  const groups = parseJsonField(checklist.groups);

  groups.forEach((group) => {
    (group.questions || []).forEach((q) => {
      const key = q._id ? q._id.toString() : q.text;
      if (normalizedRole === "executor") {
        answerMap[key] = {
          answer: q.executorAnswer,
          remark: q.executorRemark || "",
          images: q.executorImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.executor ? { id: q.answeredBy.executor } : null,
          answered_at: q.answeredAt?.executor || null,
        };
      } else {
        answerMap[key] = {
          answer: q.reviewerAnswer,
          remark: q.reviewerRemark || "",
          images: q.reviewerImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.reviewer ? { id: q.answeredBy.reviewer } : null,
          answered_at: q.answeredAt?.reviewer || null,
        };
      }
    });

    (group.sections || []).forEach((section) => {
      (section.questions || []).forEach((q) => {
        const key = q._id ? q._id.toString() : q.text;
        if (normalizedRole === "executor") {
          answerMap[key] = {
            answer: q.executorAnswer,
            remark: q.executorRemark || "",
            images: q.executorImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.executor ? { id: q.answeredBy.executor } : null,
            answered_at: q.answeredAt?.executor || null,
          };
        } else {
          answerMap[key] = {
            answer: q.reviewerAnswer,
            remark: q.reviewerRemark || "",
            images: q.reviewerImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.reviewer ? { id: q.answeredBy.reviewer } : null,
            answered_at: q.answeredAt?.reviewer || null,
          };
        }
      });
    });
  });

  return answerMap;
};

export const saveChecklistAnswers = async (projectId, phaseNum, normalizedRole, answers, userId) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true, stage_name: true },
  });

  if (!stage) throw new ApiError(404, "Stage not found for this phase");

  let checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } },
  });

  if (!checklist) {
    try {
      checklist = await ensureProjectChecklist({ projectId, stageDoc: { _id: stage.id, stage_name: stage.stage_name, stage_key: stageKey } });
    } catch (err) {
      throw new ApiError(500, `Failed to create checklist: ${err.message}`);
    }
  }

  const savedAnswers = [];
  const groups = parseJsonField(checklist.groups);

  for (const [subQuestion, answerData] of Object.entries(answers)) {
    if (!answerData || typeof answerData !== "object") continue;

    const { answer, remark, images, categoryId, severity } = answerData;
    let found = false;

    for (const group of groups) {
      for (const q of group.questions || []) {
        const matchByText = q.text === subQuestion;
        const matchById = q._id && q._id.toString() === subQuestion;

        if (matchByText || matchById) {
          if (normalizedRole === "executor") {
            if (answer !== undefined) q.executorAnswer = answer;
            if (remark !== undefined) q.executorRemark = remark || "";
            if (images !== undefined) q.executorImages = Array.isArray(images) ? images : [];
            if (!q.answeredBy) q.answeredBy = {};
            q.answeredBy.executor = userId;
            if (!q.answeredAt) q.answeredAt = {};
            q.answeredAt.executor = new Date().toISOString();
          } else {
            if (answer !== undefined) q.reviewerAnswer = answer;
            if (remark !== undefined) q.reviewerRemark = remark || "";
            if (images !== undefined) q.reviewerImages = Array.isArray(images) ? images : [];
            if (!q.answeredBy) q.answeredBy = {};
            q.answeredBy.reviewer = userId;
            if (!q.answeredAt) q.answeredAt = {};
            q.answeredAt.reviewer = new Date().toISOString();
          }
          if (categoryId !== undefined) q.categoryId = categoryId || "";
          if (severity !== undefined) q.severity = severity || "";
          found = true;
          savedAnswers.push({ question: subQuestion, updated: true });
          break;
        }
      }

      if (found) break;

      for (const section of group.sections || []) {
        for (const q of section.questions || []) {
          const matchByText = q.text === subQuestion;
          const matchById = q._id && q._id.toString() === subQuestion;

          if (matchByText || matchById) {
            if (normalizedRole === "executor") {
              if (answer !== undefined) q.executorAnswer = answer;
              if (remark !== undefined) q.executorRemark = remark || "";
              if (images !== undefined) q.executorImages = Array.isArray(images) ? images : [];
              if (!q.answeredBy) q.answeredBy = {};
              q.answeredBy.executor = userId;
              if (!q.answeredAt) q.answeredAt = {};
              q.answeredAt.executor = new Date().toISOString();
            } else {
              if (answer !== undefined) q.reviewerAnswer = answer;
              if (remark !== undefined) q.reviewerRemark = remark || "";
              if (images !== undefined) q.reviewerImages = Array.isArray(images) ? images : [];
              if (!q.answeredBy) q.answeredBy = {};
              q.answeredBy.reviewer = userId;
              if (!q.answeredAt) q.answeredAt = {};
              q.answeredAt.reviewer = new Date().toISOString();
            }
            if (categoryId !== undefined) q.categoryId = categoryId || "";
            if (severity !== undefined) q.severity = severity || "";
            found = true;
            savedAnswers.push({ question: subQuestion, updated: true });
            break;
          }
        }
        if (found) break;
      }
      if (found) break;
    }
  }

  await prisma.projectChecklist.update({
    where: { id: checklist.id },
    data: { groups }
  });

  return {
    saved_count: savedAnswers.length,
    total_attempted: Object.keys(answers).length,
  };
};

export const submitChecklistAnswers = async (projectId, phaseNum, normalizedRole) => {
  const stageKey = `stage${phaseNum}`;
  
  const existingRecord = await prisma.checklistApproval.findUnique({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } }
  });

  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true }
  });

  const wasReverted = existingRecord?.status === "reverted_to_executor";
  let totalNewDefects = 0;

  if (stage) {
    const checklist = await prisma.projectChecklist.findUnique({
      where: { projectId_stageId: { projectId, stageId: stage.id } }
    });

    if (checklist) {
      let shouldAccumulate = false;

      if (normalizedRole === "reviewer") {
        shouldAccumulate = true;
      } else if (normalizedRole === "executor") {
        const reviewerHasAnswered = existingRecord?.reviewer_submitted === true;
        shouldAccumulate = reviewerHasAnswered;
      }

      if (shouldAccumulate) {
        const groups = parseJsonField(checklist.groups);
        totalNewDefects = accumulateDefectsForChecklistGroups(groups);
        
        await prisma.projectChecklist.update({
          where: { id: checklist.id },
          data: { groups }
        });

        logger.info(
          `${normalizedRole.charAt(0).toUpperCase() + normalizedRole.slice(1)} submission: Added ${totalNewDefects} new defects to phase ${phaseNum}`
        );
      }
    }
  }

  const updateFields = {
    [`${normalizedRole}_submitted`]: true,
    [`${normalizedRole}_submitted_at`]: new Date(),
  };

  if (normalizedRole === "executor" && wasReverted) {
    updateFields.reviewer_submitted = false;
    updateFields.reviewer_submitted_at = null;
    updateFields.status = "pending";
  }

  const record = await prisma.checklistApproval.upsert({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
    update: updateFields,
    create: {
      id: newId(),
      project_id: projectId,
      phase: phaseNum,
      status: updateFields.status || "pending",
      ...updateFields
    }
  });

  const responseData = { ...record };
  if (totalNewDefects > 0) {
    responseData.defects_added = totalNewDefects;
  }

  return responseData;
};

export const getSubmissionStatus = async (projectId, phaseNum, normalizedRole) => {
  const record = await prisma.checklistApproval.findUnique({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
  });

  return {
    is_submitted: record?.[`${normalizedRole}_submitted`] || false,
    submitted_at: record?.[`${normalizedRole}_submitted_at`] || null,
  };
};
