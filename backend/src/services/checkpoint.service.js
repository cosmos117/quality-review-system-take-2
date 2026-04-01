import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { newId } from "../utils/newId.js";

// Helper to safely parse json fields
const parseJsonField = (field) => {
    if (!field) return {};
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

export async function createCheckpoint(checklistId, { question, categoryId }) {
  const checklist = await prisma.checklist.findUnique({
    where: { id: checklistId },
    select: { id: true },
  });
  if (!checklist) throw new ApiError(404, "Checklist not found");

  return prisma.checkpoint.create({
    data: {
      id: newId(),
      checklistId,
      question: question.trim(),
      categoryId: categoryId || null,
      executorResponse: {},
      reviewerResponse: {},
      defect: {
        isDetected: false,
        categoryId: null,
        severity: null,
        detectedAt: null,
        historyCount: 0
      }
    }
  });
}

export async function getCheckpointsByChecklistId(checklistId) {
  return prisma.checkpoint.findMany({
    where: { checklistId },
    orderBy: { createdAt: "asc" }
  });
}

export async function getCheckpointById(checkpointId) {
  const checkpoint = await prisma.checkpoint.findUnique({
    where: { id: checkpointId }
  });
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");
  return checkpoint;
}

export async function updateCheckpointResponse(checkpointId, data) {
  const { executorResponse, reviewerResponse, defectCategoryId, categoryId, severity } = data;

  const checkpoint = await prisma.checkpoint.findUnique({
    where: { id: checkpointId }
  });
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  const currentExecutorResponse = parseJsonField(checkpoint.executorResponse);
  const currentReviewerResponse = parseJsonField(checkpoint.reviewerResponse);
  const currentDefect = parseJsonField(checkpoint.defect);

  let updatedExecutorResponse = { ...currentExecutorResponse };
  if (executorResponse) {
    updatedExecutorResponse = {
      ...updatedExecutorResponse,
      ...executorResponse,
      respondedAt: new Date().toISOString()
    };
    if (Array.isArray(executorResponse.images)) {
      updatedExecutorResponse.images = executorResponse.images;
    }
  }

  let updatedReviewerResponse = { ...currentReviewerResponse };
  if (reviewerResponse) {
    updatedReviewerResponse = {
      ...updatedReviewerResponse,
      ...reviewerResponse,
      reviewedAt: new Date().toISOString()
    };
    if (Array.isArray(reviewerResponse.images)) {
      updatedReviewerResponse.images = reviewerResponse.images;
    }
  }

  let updatedCategoryId = checkpoint.categoryId;
  if (categoryId && categoryId.trim()) {
    updatedCategoryId = categoryId.trim();
  }

  let updatedDefect = { ...currentDefect, historyCount: currentDefect.historyCount || 0 };
  if (severity && ["Critical", "Non-Critical"].includes(severity)) {
    updatedDefect.severity = severity;
  }

  if (updatedExecutorResponse.answer !== undefined && updatedExecutorResponse.answer !== null &&
      updatedReviewerResponse.answer !== undefined && updatedReviewerResponse.answer !== null) {
      
    const answersMatch = updatedExecutorResponse.answer === updatedReviewerResponse.answer;
    const wasDefectDetected = !!updatedDefect.isDetected;
    updatedDefect.isDetected = !answersMatch;

    if (!answersMatch) {
      updatedDefect.detectedAt = new Date().toISOString();
      if (!wasDefectDetected) {
        updatedDefect.historyCount += 1;
      }
      if (defectCategoryId) updatedDefect.categoryId = defectCategoryId;
      if (!updatedDefect.categoryId && updatedCategoryId) {
        updatedDefect.categoryId = updatedCategoryId;
      }
    } else {
      updatedDefect.isDetected = false;
      updatedDefect.categoryId = null;
      updatedDefect.detectedAt = null;
    }
  }

  const updatedCheckpoint = await prisma.checkpoint.update({
    where: { id: checkpointId },
    data: {
      executorResponse: updatedExecutorResponse,
      reviewerResponse: updatedReviewerResponse,
      categoryId: updatedCategoryId,
      defect: updatedDefect
    }
  });

  return updatedCheckpoint;
}

export async function deleteCheckpoint(checkpointId) {
  const checkpoint = await prisma.checkpoint.findUnique({ where: { id: checkpointId } });
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");
  
  await prisma.checkpoint.delete({ where: { id: checkpointId } });
}

export async function assignDefectCategory(checkpointId, { categoryId, severity }) {
  const checkpoint = await prisma.checkpoint.findUnique({ where: { id: checkpointId } });
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  const currentDefect = parseJsonField(checkpoint.defect);
  
  const updatedDefect = {
    ...currentDefect,
    isDetected: true,
    categoryId: categoryId.trim(),
    detectedAt: new Date().toISOString(),
    historyCount: Math.max(currentDefect.historyCount || 0, 1)
  };

  if (severity) updatedDefect.severity = severity;

  const updatedCheckpoint = await prisma.checkpoint.update({
    where: { id: checkpointId },
    data: { defect: updatedDefect }
  });

  return updatedCheckpoint;
}

export async function getDefectStatsByChecklist(checklistId) {
  const checkpoints = await prisma.checkpoint.findMany({
    where: { checklistId },
    select: { question: true, defect: true }
  });
  
  const totalCheckpoints = checkpoints.length;

  const checklist = await prisma.checklist.findUnique({
    where: { id: checklistId },
    include: {
      stage: { select: { project_id: true, stage_key: true } }
    }
  });
  
  if (!checklist || !checklist.stage) throw new ApiError(404, "Checklist or stage not found");

  const projectId = checklist.stage.project_id;
  
  // Try to parse phase number from stageKey
  const stageKey = checklist.stage.stage_key || "";
  const match = stageKey.match(/stage(\d+)/i);
  const phase = match ? parseInt(match[1], 10) : 1; 

  // Fallback Phase
  const allAnswers = await prisma.checklistAnswer.findMany({
    where: { project_id: projectId, phase }
  });

  const answersByQuestion = {};
  for (const ans of allAnswers) {
    if (!answersByQuestion[ans.sub_question]) answersByQuestion[ans.sub_question] = {};
    answersByQuestion[ans.sub_question][ans.role] = ans.answer;
  }

  let totalDefectsInHistory = 0;
  for (const cp of checkpoints) {
    const roleAnswers = answersByQuestion[cp.question];
    if (
      roleAnswers &&
      roleAnswers.executor !== undefined &&
      roleAnswers.reviewer !== undefined &&
      roleAnswers.executor !== roleAnswers.reviewer
    ) {
      totalDefectsInHistory++;
    }
  }

  const defectRate = totalCheckpoints > 0
    ? ((totalDefectsInHistory / totalCheckpoints) * 100).toFixed(2)
    : "0.00";

  return { checklistId, totalCheckpoints, totalDefectsInHistory, defectRate: parseFloat(defectRate) };
}

export async function suggestDefectCategory(checkpointId, remark) {
  if (checkpointId !== "dummy") {
    const checkpoint = await prisma.checkpoint.findUnique({
      where: { id: checkpointId },
      select: { id: true }
    });
    if (!checkpoint) throw new ApiError(404, "Checkpoint not found");
  }

  const { suggestCategory } = await import("../categorizationService.js");
  const template = await prisma.template.findFirst();

  if (!template || !template.defectCategories) {
    return {
      suggestedCategoryId: null, confidence: 0, autoFill: false,
      reason: "No categories available in template",
    };
  }

  const defectCategories = parseJsonField(template.defectCategories);

  const suggestion = suggestCategory(remark, defectCategories);
  return {
    suggestedCategoryId: suggestion.suggestedCategoryId,
    categoryName: suggestion.categoryName,
    confidence: suggestion.confidence,
    autoFill: suggestion.autoFill,
    matchCount: suggestion.matchCount,
    tokenCount: suggestion.tokenCount,
  };
}
