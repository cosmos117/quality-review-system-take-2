import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as analyticsService from "../services/analytics.service.js";

export const getProjectAnalysis = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const data = await analyticsService.getProjectAnalysis(projectId);
  const message = data.summary
    ? "Project analysis retrieved successfully"
    : data.defectsByPhase.length === 0 ? "No stages found for this project" : "No checklists found for this project";
  return res.status(200).json(new ApiResponse(200, data, message));
});

export const getDefectsPerPhase = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const result = await analyticsService.getDefectsPerPhase(projectId);
  return res.status(200).json(new ApiResponse(200, result, "Defects per phase retrieved successfully"));
});

export const getDefectsPerChecklist = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const result = await analyticsService.getDefectsPerChecklist(projectId);
  return res.status(200).json(new ApiResponse(200, result, "Defects per checklist retrieved successfully"));
});

export const getCategoryDistribution = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const data = await analyticsService.getCategoryDistribution(projectId);
  const message = data.totalDefects === 0 ? "No defects found" : "Category distribution retrieved successfully";
  return res.status(200).json(new ApiResponse(200, data, message));
});
