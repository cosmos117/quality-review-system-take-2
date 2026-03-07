import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as projectChecklistService from "../services/projectChecklist.service.js";

// Re-export shared helpers so existing importers don't break
export const ensureProjectChecklist = projectChecklistService.ensureProjectChecklist;
export const mapTemplateToGroups = projectChecklistService.mapTemplateToGroups;
export const inferStageKey = projectChecklistService.inferStageKey;

const getProjectChecklist = asyncHandler(async (req, res) => {
  const { projectId, stageId } = req.params;
  if (
    !mongoose.isValidObjectId(projectId) ||
    !mongoose.isValidObjectId(stageId)
  ) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  const data = await projectChecklistService.getProjectChecklist(projectId, stageId);
  return res.status(200).json(new ApiResponse(200, data, "Project checklist fetched successfully"));
});

const updateExecutorAnswer = asyncHandler(async (req, res) => {
  const { projectId, stageId, groupId, questionId } = req.params;
  const { answer, remark, images, categoryId, severity } = req.body;
  if (!mongoose.isValidObjectId(projectId) || !mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  if (!mongoose.isValidObjectId(groupId) || !mongoose.isValidObjectId(questionId)) {
    throw new ApiError(400, "Invalid groupId or questionId");
  }
  if (!projectChecklistService.allowedExecutorAnswers.includes(answer === undefined ? null : answer)) {
    throw new ApiError(400, "executorAnswer must be Yes, No, NA, or null");
  }
  const userId = req.user?._id || null;
  const data = await projectChecklistService.updateExecutorAnswer(
    projectId, stageId, groupId, questionId,
    { answer, remark, images, categoryId, severity },
    userId,
  );
  return res.status(200).json(new ApiResponse(200, data, "Executor response updated"));
});

const updateReviewerStatus = asyncHandler(async (req, res) => {
  const { projectId, stageId, groupId, questionId } = req.params;
  const { answer, status, remark, images, categoryId, severity } = req.body;
  if (!mongoose.isValidObjectId(projectId) || !mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  if (!mongoose.isValidObjectId(groupId) || !mongoose.isValidObjectId(questionId)) {
    throw new ApiError(400, "Invalid groupId or questionId");
  }
  if (answer !== undefined && !["Yes", "No", "NA", null].includes(answer)) {
    throw new ApiError(400, "reviewerAnswer must be Yes, No, NA, or null");
  }
  if (!projectChecklistService.allowedReviewerStatuses.includes(status === undefined ? null : status)) {
    throw new ApiError(400, "reviewerStatus must be Approved, Rejected, or null");
  }
  const userId = req.user?._id || null;
  const data = await projectChecklistService.updateReviewerStatus(
    projectId, stageId, groupId, questionId,
    { answer, status, remark, images, categoryId, severity },
    userId,
  );
  return res.status(200).json(new ApiResponse(200, data, "Reviewer decision updated"));
});

const getChecklistIterations = asyncHandler(async (req, res) => {
  const { projectId, stageId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  if (!mongoose.isValidObjectId(stageId)) throw new ApiError(400, "Invalid stageId");
  const data = await projectChecklistService.getChecklistIterations(projectId, stageId);
  const message = data.totalIterations === undefined ? "No checklist found" : "Iterations fetched successfully";
  return res.status(200).json(new ApiResponse(200, data, message));
});

const getDefectRatesPerIteration = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const data = await projectChecklistService.getDefectRatesPerIteration(projectId, phaseNum);
  const message = data.current ? "Defect rates per iteration fetched successfully" : "No stage found for this phase";
  return res.status(200).json(new ApiResponse(200, data, message));
});

const getOverallDefectRate = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const data = await projectChecklistService.getOverallDefectRate(projectId);
  const message = data.phaseBreakdown.length === 0
    ? "No stages found for this project"
    : "Overall defect rate fetched successfully";
  return res.status(200).json(new ApiResponse(200, data, message));
});

export {
  getProjectChecklist,
  updateExecutorAnswer,
  updateReviewerStatus,
  getChecklistIterations,
  getDefectRatesPerIteration,
  getOverallDefectRate,
};
