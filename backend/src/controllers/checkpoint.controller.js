const isValidObjectId = (id) => /^[a-fA-F0-9]{24}$/.test(id);
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as checkpointService from "../services/checkpoint.service.js";

export const createCheckpoint = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { question, categoryId } = req.body;

  if (!isValidObjectId(checklistId)) throw new ApiError(400, "Invalid checklistId");
  if (!question?.trim()) throw new ApiError(400, "question is required");

  const checkpoint = await checkpointService.createCheckpoint(checklistId, { question, categoryId });
  return res.status(201).json(new ApiResponse(201, checkpoint, "Checkpoint created successfully"));
});

export const getCheckpointsByChecklistId = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  if (!isValidObjectId(checklistId)) throw new ApiError(400, "Invalid checklist id");

  const checkpoints = await checkpointService.getCheckpointsByChecklistId(checklistId);
  return res.status(200).json(new ApiResponse(200, checkpoints, "Checkpoints fetched successfully"));
});

export const getCheckpointById = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  if (!isValidObjectId(checkpointId)) throw new ApiError(400, "Invalid checkpoint id");

  const checkpoint = await checkpointService.getCheckpointById(checkpointId);
  return res.status(200).json(new ApiResponse(200, checkpoint, "Checkpoint fetched successfully"));
});

export const updateCheckpointResponse = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  if (!isValidObjectId(checkpointId)) throw new ApiError(400, "Invalid checkpoint id");

  const checkpoint = await checkpointService.updateCheckpointResponse(checkpointId, req.body);
  return res.status(200).json(new ApiResponse(200, checkpoint, "Checkpoint updated successfully"));
});

export const deleteCheckpoint = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  if (!isValidObjectId(checkpointId)) throw new ApiError(400, "Invalid checkpoint id");

  await checkpointService.deleteCheckpoint(checkpointId);
  return res.status(200).json(new ApiResponse(200, null, "Checkpoint deleted successfully"));
});

export const assignDefectCategory = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { categoryId, severity } = req.body;

  if (!isValidObjectId(checkpointId)) throw new ApiError(400, "Invalid checkpoint id");
  if (!categoryId || typeof categoryId !== "string" || !categoryId.trim()) {
    throw new ApiError(400, "categoryId is required and must be a non-empty string");
  }
  if (severity && !["Critical", "Non-Critical"].includes(severity)) {
    throw new ApiError(400, "Invalid severity. Must be 'Critical' or 'Non-Critical'");
  }

  const checkpoint = await checkpointService.assignDefectCategory(checkpointId, { categoryId, severity });
  return res.status(200).json(new ApiResponse(200, checkpoint, "Defect category assigned successfully"));
});

export const getDefectStatsByChecklist = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  if (!isValidObjectId(checklistId)) throw new ApiError(400, "Invalid checklistId");

  const stats = await checkpointService.getDefectStatsByChecklist(checklistId);
  return res.status(200).json(new ApiResponse(200, stats, "Defect statistics fetched successfully"));
});

export const suggestDefectCategory = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { remark } = req.body;

  if (checkpointId !== "dummy" && !isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpointId");
  }
  if (!remark || typeof remark !== "string" || remark.trim().length === 0) {
    return res.status(200).json(new ApiResponse(200, {
      suggestedCategoryId: null, confidence: 0, autoFill: false,
      reason: "Remark is empty or invalid",
    }));
  }

  const suggestion = await checkpointService.suggestDefectCategory(checkpointId, remark);
  return res.status(200).json(new ApiResponse(200, suggestion, "Category suggestion generated successfully"));
});
