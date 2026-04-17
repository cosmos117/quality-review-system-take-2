import prisma from "../config/prisma.js";
import {
  ensureProjectChecklist,
  getOverallDefectRate,
} from "./projectChecklist.service.js";
import { accumulateDefectsForChecklistGroups } from "./defectUtility.service.js";
import { ApiError } from "../utils/ApiError.js";
import logger from "../utils/logger.js";
import { newId } from "../utils/newId.js";

const parseJsonField = (field) => {
  if (!field) return [];
  if (typeof field === "string") {
    try {
      return JSON.parse(field);
    } catch (_) {
      return [];
    }
  }
  return field;
};

async function resolveProjectChecklist(projectId, phaseNum) {
  const stageKey = `stage${phaseNum}`;

  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true, stage_name: true, stage_key: true },
  });

  if (!stage) return { stage: null, checklist: null };

  let checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } },
  });

  if (!checklist) {
    checklist = await ensureProjectChecklist({
      projectId,
      stageDoc: {
        _id: stage.id,
        stage_name: stage.stage_name,
        stage_key: stage.stage_key || stageKey,
      },
    });
  }

  return { stage, checklist };
}

function upsertRoleAnswer(question, role, answerData, userId) {
  const hasAnswer = Object.prototype.hasOwnProperty.call(answerData, "answer");
  const hasRemark = Object.prototype.hasOwnProperty.call(answerData, "remark");
  const hasImages = Object.prototype.hasOwnProperty.call(answerData, "images");
  const hasCategory = Object.prototype.hasOwnProperty.call(
    answerData,
    "categoryId",
  );
  const hasSeverity = Object.prototype.hasOwnProperty.call(
    answerData,
    "severity",
  );

  if (role === "executor") {
    if (hasAnswer) question.executorAnswer = answerData.answer;
    if (hasRemark) question.executorRemark = answerData.remark || "";
    if (hasImages)
      question.executorImages = Array.isArray(answerData.images)
        ? answerData.images
        : [];
  } else {
    if (hasAnswer) question.reviewerAnswer = answerData.answer;
    if (hasRemark) question.reviewerRemark = answerData.remark || "";
    if (hasImages)
      question.reviewerImages = Array.isArray(answerData.images)
        ? answerData.images
        : [];
  }

  if (hasCategory) question.categoryId = answerData.categoryId || "";
  if (hasSeverity) question.severity = answerData.severity || "";

  if (!question.answeredBy) question.answeredBy = {};
  if (!question.answeredAt) question.answeredAt = {};

  if (userId) {
    question.answeredBy[role] = userId;
  }
  question.answeredAt[role] = new Date().toISOString();
}

export async function getChecklistAnswers(projectId, phaseNum, role) {
  const { stage, checklist } = await resolveProjectChecklist(
    projectId,
    phaseNum,
  );
  if (!stage || !checklist) return {};

  const answerMap = {};
  const groups = parseJsonField(checklist.groups);

  const writeAnswer = (question) => {
    const key = question._id ? question._id.toString() : question.text || "";
    if (!key) return;

    if (role === "executor") {
      answerMap[key] = {
        answer: question.executorAnswer,
        remark: question.executorRemark || "",
        images: Array.isArray(question.executorImages)
          ? question.executorImages
          : [],
        categoryId: question.categoryId || "",
        severity: question.severity || "",
        answered_by: question.answeredBy?.executor
          ? { id: question.answeredBy.executor }
          : null,
        answered_at: question.answeredAt?.executor || null,
      };
      return;
    }

    answerMap[key] = {
      answer: question.reviewerAnswer,
      remark: question.reviewerRemark || "",
      images: Array.isArray(question.reviewerImages)
        ? question.reviewerImages
        : [],
      categoryId: question.categoryId || "",
      severity: question.severity || "",
      answered_by: question.answeredBy?.reviewer
        ? { id: question.answeredBy.reviewer }
        : null,
      answered_at: question.answeredAt?.reviewer || null,
    };
  };

  for (const group of groups || []) {
    for (const question of group.questions || []) writeAnswer(question);
    for (const section of group.sections || []) {
      for (const question of section.questions || []) writeAnswer(question);
    }
  }

  return answerMap;
}

export async function saveChecklistAnswers(
  projectId,
  phaseNum,
  role,
  answers,
  userId,
) {
  const { stage, checklist } = await resolveProjectChecklist(
    projectId,
    phaseNum,
  );
  if (!stage) throw new ApiError(404, "Stage not found for this phase");
  if (!checklist) throw new ApiError(404, "Checklist not found for this phase");

  const groups = parseJsonField(checklist.groups);
  const entries = Object.entries(answers || {});

  let savedCount = 0;

  for (const [subQuestion, answerData] of entries) {
    if (!answerData || typeof answerData !== "object") continue;

    let found = false;

    for (const group of groups || []) {
      for (const question of group.questions || []) {
        const key = question._id ? question._id.toString() : question.text;
        if (subQuestion === key || subQuestion === question.text) {
          upsertRoleAnswer(question, role, answerData, userId);
          savedCount += 1;
          found = true;
          break;
        }
      }
      if (found) break;

      for (const section of group.sections || []) {
        for (const question of section.questions || []) {
          const key = question._id ? question._id.toString() : question.text;
          if (subQuestion === key || subQuestion === question.text) {
            upsertRoleAnswer(question, role, answerData, userId);
            savedCount += 1;
            found = true;
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
    data: { groups },
  });

  getOverallDefectRate(projectId).catch((err) => {
    logger.error(
      `Failed to refresh overall defect rate for project ${projectId}: ${err.message}`,
    );
  });

  return {
    saved_count: savedCount,
    total_attempted: entries.length,
  };
}

export async function submitChecklistAnswers(projectId, phaseNum, role) {
  const { stage, checklist } = await resolveProjectChecklist(
    projectId,
    phaseNum,
  );
  if (!stage) throw new ApiError(404, "Stage not found for this phase");

  const existingRecord = await prisma.checklistApproval.findUnique({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
  });

  const wasReverted = existingRecord?.status === "reverted_to_executor";
  let totalNewDefects = 0;

  if (checklist) {
    const groups = parseJsonField(checklist.groups);
    let shouldAccumulate = false;

    if (role === "reviewer") {
      shouldAccumulate = true;
    } else if (role === "executor") {
      shouldAccumulate = existingRecord?.reviewer_submitted === true;
    }

    if (shouldAccumulate) {
      totalNewDefects = accumulateDefectsForChecklistGroups(groups);

      await prisma.projectChecklist.update({
        where: { id: checklist.id },
        data: { groups },
      });

      logger.info(
        `${role.charAt(0).toUpperCase() + role.slice(1)} submission: Added ${totalNewDefects} new defects to phase ${phaseNum}`,
      );
    }
  }

  const updateFields = {
    [`${role}_submitted`]: true,
    [`${role}_submitted_at`]: new Date(),
  };

  if (role === "executor" && wasReverted) {
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
      status: updateFields.status || existingRecord?.status || "pending",
      ...updateFields,
    },
  });

  getOverallDefectRate(projectId).catch((err) => {
    logger.error(
      `Failed to refresh overall defect rate for project ${projectId}: ${err.message}`,
    );
  });

  return {
    ...record,
    ...(totalNewDefects > 0 ? { defects_added: totalNewDefects } : {}),
  };
}

export async function getSubmissionStatus(projectId, phaseNum, role) {
  const record = await prisma.checklistApproval.findUnique({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
  });

  return {
    is_submitted: record?.[`${role}_submitted`] || false,
    submitted_at: record?.[`${role}_submitted_at`] || null,
  };
}
