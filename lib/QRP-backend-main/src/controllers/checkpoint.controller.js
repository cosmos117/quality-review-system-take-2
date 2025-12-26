import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Checkpoint from "../models/checkpoint.models.js";
import Checklist from "../models/checklist.models.js";

/**
 * CREATE CHECKPOINT
 * POST /api/v1/checklists/:checklistId/checkpoints
 * Creates a new checkpoint (question) within a checklist
 */
export const createCheckpoint = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { question, categoryId } = req.body;

  if (!mongoose.isValidObjectId(checklistId)) {
    throw new ApiError(400, "Invalid checklistId");
  }

  if (!question?.trim()) {
    throw new ApiError(400, "question is required");
  }

  // Verify checklist exists
  const checklist = await Checklist.findById(checklistId);
  if (!checklist) {
    throw new ApiError(404, "Checklist not found");
  }

  // Create checkpoint
  const checkpoint = await Checkpoint.create({
    checklistId: checklistId,
    question: question.trim(),
    categoryId: categoryId || undefined,
    executorResponse: {},
    reviewerResponse: {},
  });

  return res
    .status(201)
    .json(new ApiResponse(201, checkpoint, "Checkpoint created successfully"));
});

/**
 * GET CHECKPOINTS BY CHECKLIST ID
 * GET /api/v1/checklists/:checklistId/checkpoints
 * Fetches all checkpoints for a specific checklist (without image data for performance)
 */
export const getCheckpointsByChecklistId = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;

  if (!mongoose.isValidObjectId(checklistId)) {
    throw new ApiError(400, "Invalid checklist id");
  }

  // Exclude large image buffers from response for performance
  const checkpoints = await Checkpoint.find({ checklistId: checklistId })
    .select("-executorResponse.images.data -reviewerResponse.images.data")
    .sort({ createdAt: 1 });

  return res
    .status(200)
    .json(
      new ApiResponse(200, checkpoints, "Checkpoints fetched successfully")
    );
});

/**
 * GET CHECKPOINT BY ID
 * GET /api/v1/checkpoints/:checkpointId
 * Fetches a single checkpoint by ID (without image data)
 */
export const getCheckpointById = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  const checkpoint = await Checkpoint.findById(checkpointId).select(
    "-executorResponse.images.data -reviewerResponse.images.data"
  );

  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  return res
    .status(200)
    .json(new ApiResponse(200, checkpoint, "Checkpoint fetched successfully"));
});

/**
 * UPDATE CHECKPOINT RESPONSE
 * PATCH /api/v1/checkpoints/:checkpointId
 * Updates executor or reviewer response for a checkpoint
 * Automatically detects defects when answers differ
 * Body: { executorResponse?: {...}, reviewerResponse?: {...}, defectCategoryId?: string }
 */
export const updateCheckpointResponse = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { executorResponse, reviewerResponse, defectCategoryId } = req.body;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  // Update executor response
  if (executorResponse) {
    checkpoint.executorResponse = {
      ...checkpoint.executorResponse,
      ...executorResponse,
      respondedAt: new Date(),
    };
  }

  // Handle executor images from multipart upload (if using multer)
  if (req.files?.length) {
    req.files.forEach((file) => {
      checkpoint.executorResponse.images.push({
        data: file.buffer,
        contentType: file.mimetype,
      });
    });
  }

  // Update reviewer response
  if (reviewerResponse) {
    checkpoint.reviewerResponse = {
      ...checkpoint.reviewerResponse,
      ...reviewerResponse,
      reviewedAt: new Date(),
    };
  }

  // Auto-detect defects: compare executor and reviewer answers
  // Defect = executor answer ≠ reviewer answer
  if (
    checkpoint.executorResponse.answer !== null &&
    checkpoint.reviewerResponse.answer !== null
  ) {
    const answersMatch =
      checkpoint.executorResponse.answer === checkpoint.reviewerResponse.answer;
    checkpoint.defect.isDetected = !answersMatch;

    if (!answersMatch) {
      // Defect detected
      checkpoint.defect.detectedAt = new Date();
      // If defectCategoryId provided, assign it; otherwise keep existing or null
      if (defectCategoryId) {
        checkpoint.defect.categoryId = defectCategoryId;
      }
    } else {
      // No defect (answers match), clear defect data
      checkpoint.defect.isDetected = false;
      checkpoint.defect.categoryId = null;
      checkpoint.defect.detectedAt = null;
    }
  }

  await checkpoint.save();

  return res
    .status(200)
    .json(new ApiResponse(200, checkpoint, "Checkpoint updated successfully"));
});

/**
 * DELETE CHECKPOINT
 * DELETE /api/v1/checkpoints/:checkpointId
 * Deletes a checkpoint by ID
 */
export const deleteCheckpoint = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  await checkpoint.deleteOne();

  return res
    .status(200)
    .json(new ApiResponse(200, null, "Checkpoint deleted successfully"));
});

/**
 * ASSIGN DEFECT CATEGORY
 * PATCH /api/v1/checkpoints/:checkpointId/defect-category
 * Assigns or updates a defect category for a checkpoint
 * Body: { categoryId: string } - category ID from template
 */
export const assignDefectCategory = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { categoryId } = req.body;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  if (!categoryId || typeof categoryId !== "string" || !categoryId.trim()) {
    throw new ApiError(
      400,
      "categoryId is required and must be a non-empty string"
    );
  }

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  // Mark defect as detected and assign category (allows manual defect assignment by reviewer)
  checkpoint.defect.isDetected = true;
  checkpoint.defect.categoryId = categoryId.trim();
  checkpoint.defect.detectedAt = new Date();
  await checkpoint.save();

  return res
    .status(200)
    .json(
      new ApiResponse(200, checkpoint, "Defect category assigned successfully")
    );
});
