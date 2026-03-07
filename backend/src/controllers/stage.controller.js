import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as stageService from "../services/stage.service.js";

const listStagesForProject = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }
  const result = await stageService.listStagesForProject(projectId, req.user?._id);
  return res.status(200).json(result);
});

const getStageById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    throw new ApiError(400, "Invalid stage id");
  }
  const stage = await stageService.getStageById(id);
  return res.status(200).json(new ApiResponse(200, stage, "Stage fetched successfully"));
});

const createStage = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { stage_name, stage_key, description, status } = req.body;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }
  if (!stage_name?.trim()) {
    throw new ApiError(400, "stage_name is required");
  }

  const created_by = req.user?._id;
  if (!created_by) throw new ApiError(401, "Not authenticated");

  const stage = await stageService.createStage(
    projectId,
    { stage_name, stage_key, description, status },
    created_by,
  );
  return res.status(201).json(new ApiResponse(201, stage, "Stage created successfully"));
});

const updateStage = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    throw new ApiError(400, "Invalid stage id");
  }
  const { stage_name, description, status } = req.body;
  const stage = await stageService.updateStage(id, { stage_name, description, status });
  return res.status(200).json(new ApiResponse(200, stage, "Stage updated successfully"));
});

const deleteStage = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    throw new ApiError(400, "Invalid stage id");
  }
  const deleted = await stageService.deleteStage(id);
  return res.status(200).json(new ApiResponse(200, deleted, "Stage deleted successfully"));
});

const migrateStageCounters = asyncHandler(async (req, res) => {
  const result = await stageService.migrateStageCounters();
  return res.status(200).json(
    new ApiResponse(200, { matchedCount: result.matchedCount, modifiedCount: result.modifiedCount }, "Stage counters migration completed"),
  );
});

export {
  listStagesForProject,
  getStageById,
  createStage,
  updateStage,
  deleteStage,
  migrateStageCounters,
};
