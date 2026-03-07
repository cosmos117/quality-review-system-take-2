import Checkpoint from "../models/checkpoint.models.js";
import Checklist from "../models/checklist.models.js";
import ChecklistAnswer from "../models/checklistAnswer.models.js";
import { ApiError } from "../utils/ApiError.js";

export async function createCheckpoint(checklistId, { question, categoryId }) {
  const checklist = await Checklist.findById(checklistId).select("_id").lean();
  if (!checklist) throw new ApiError(404, "Checklist not found");

  return Checkpoint.create({
    checklistId,
    question: question.trim(),
    categoryId: categoryId || undefined,
    executorResponse: {},
    reviewerResponse: {},
  });
}

export async function getCheckpointsByChecklistId(checklistId) {
  return Checkpoint.find({ checklistId }).sort({ createdAt: 1 }).lean();
}

export async function getCheckpointById(checkpointId) {
  const checkpoint = await Checkpoint.findById(checkpointId).lean();
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");
  return checkpoint;
}

export async function updateCheckpointResponse(checkpointId, data) {
  const { executorResponse, reviewerResponse, defectCategoryId, categoryId, severity } = data;

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  if (executorResponse) {
    checkpoint.executorResponse = {
      ...checkpoint.executorResponse,
      ...executorResponse,
      respondedAt: new Date(),
    };
    if (Array.isArray(executorResponse.images)) {
      checkpoint.executorResponse.images = executorResponse.images;
    }
  }

  if (reviewerResponse) {
    checkpoint.reviewerResponse = {
      ...checkpoint.reviewerResponse,
      ...reviewerResponse,
      reviewedAt: new Date(),
    };
    if (Array.isArray(reviewerResponse.images)) {
      checkpoint.reviewerResponse.images = reviewerResponse.images;
    }
  }

  if (categoryId && categoryId.trim()) {
    checkpoint.categoryId = categoryId.trim();
  }

  if (severity && ["Critical", "Non-Critical"].includes(severity)) {
    checkpoint.defect.severity = severity;
  }

  if (
    checkpoint.executorResponse.answer !== null &&
    checkpoint.reviewerResponse.answer !== null
  ) {
    const answersMatch = checkpoint.executorResponse.answer === checkpoint.reviewerResponse.answer;
    const wasDefectDetected = checkpoint.defect.isDetected;
    checkpoint.defect.isDetected = !answersMatch;

    if (!answersMatch) {
      checkpoint.defect.detectedAt = new Date();
      if (!wasDefectDetected) {
        checkpoint.defect.historyCount = (checkpoint.defect.historyCount || 0) + 1;
      }
      if (defectCategoryId) checkpoint.defect.categoryId = defectCategoryId;
      if (!checkpoint.defect.categoryId && checkpoint.categoryId) {
        checkpoint.defect.categoryId = checkpoint.categoryId;
      }
    } else {
      checkpoint.defect.isDetected = false;
      checkpoint.defect.categoryId = null;
      checkpoint.defect.detectedAt = null;
    }
  }

  await checkpoint.save();
  return checkpoint;
}

export async function deleteCheckpoint(checkpointId) {
  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");
  await checkpoint.deleteOne();
}

export async function assignDefectCategory(checkpointId, { categoryId, severity }) {
  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  checkpoint.defect.isDetected = true;
  checkpoint.defect.categoryId = categoryId.trim();
  checkpoint.defect.detectedAt = new Date();
  if (severity) checkpoint.defect.severity = severity;
  if (checkpoint.defect.historyCount === 0) checkpoint.defect.historyCount = 1;

  await checkpoint.save();
  return checkpoint;
}

export async function getDefectStatsByChecklist(checklistId) {
  const checkpoints = await Checkpoint.find({ checklistId }).select("question defect").lean();
  const totalCheckpoints = checkpoints.length;

  const checklist = await Checklist.findById(checklistId).populate("stage_id", "project_id phase").lean();
  if (!checklist || !checklist.stage_id) throw new ApiError(404, "Checklist or stage not found");

  const stage = checklist.stage_id;
  const projectId = stage.project_id;
  const phase = stage.phase;

  const allAnswers = await ChecklistAnswer.find({ project_id: projectId, phase }).lean();

  const answersByQuestion = {};
  allAnswers.forEach((ans) => {
    if (!answersByQuestion[ans.sub_question]) answersByQuestion[ans.sub_question] = {};
    answersByQuestion[ans.sub_question][ans.role] = ans.answer;
  });

  let totalDefectsInHistory = 0;
  checkpoints.forEach((cp) => {
    const roleAnswers = answersByQuestion[cp.question];
    if (
      roleAnswers &&
      roleAnswers.executor !== undefined &&
      roleAnswers.reviewer !== undefined &&
      roleAnswers.executor !== roleAnswers.reviewer
    ) {
      totalDefectsInHistory++;
    }
  });

  const defectRate = totalCheckpoints > 0
    ? ((totalDefectsInHistory / totalCheckpoints) * 100).toFixed(2)
    : "0.00";

  return { checklistId, totalCheckpoints, totalDefectsInHistory, defectRate: parseFloat(defectRate) };
}

export async function suggestDefectCategory(checkpointId, remark) {
  if (checkpointId !== "dummy") {
    const checkpoint = await Checkpoint.findById(checkpointId).select("_id").lean();
    if (!checkpoint) throw new ApiError(404, "Checkpoint not found");
  }

  const { suggestCategory } = await import("../services/categorizationService.js");
  const Template = (await import("../models/template.models.js")).default;
  const template = await Template.findOne().lean();

  if (!template || !template.defectCategories) {
    return {
      suggestedCategoryId: null, confidence: 0, autoFill: false,
      reason: "No categories available in template",
    };
  }

  const suggestion = suggestCategory(remark, template.defectCategories);
  return {
    suggestedCategoryId: suggestion.suggestedCategoryId,
    categoryName: suggestion.categoryName,
    confidence: suggestion.confidence,
    autoFill: suggestion.autoFill,
    matchCount: suggestion.matchCount,
    tokenCount: suggestion.tokenCount,
  };
}
