const isValidObjectId = (id) => /^[a-fA-F0-9]{24}$/.test(id);
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as approvalService from "../services/approval.service.js";

const compareAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const data = await approvalService.compareAnswers(projectId, phaseNum);
  return res.status(200).json(new ApiResponse(200, data, "Comparison complete"));
});

const requestApproval = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, notes } = req.body;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const data = await approvalService.requestApproval(projectId, phaseNum, notes);
  return res.status(200).json(new ApiResponse(200, data, "Approval requested"));
});

const approve = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.body;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const userId = req.user?._id || null;
  const data = await approvalService.approve(projectId, phaseNum, userId);
  return res.status(200).json(new ApiResponse(200, data, "Approved and advanced to next phase"));
});

const revertToExecutor = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, notes } = req.body;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const userId = req.user?._id || null;
  const data = await approvalService.revertToExecutor(projectId, phaseNum, notes, userId);
  return res.status(200).json(new ApiResponse(200, data, "Reverted to Executor - Previous iteration saved with accumulated defects"));
});

const getApprovalStatus = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const data = await approvalService.getApprovalStatus(projectId, phaseNum);
  if (!data) return res.status(200).json(new ApiResponse(200, null, "No approval record found"));
  return res.status(200).json(new ApiResponse(200, data, "Approval status fetched"));
});

const getRevertCount = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");
  const revertCount = await approvalService.getRevertCount(projectId, phaseNum);
  return res.status(200).json(new ApiResponse(200, { revertCount }, "Revert count fetched"));
});

const incrementRevertCount = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.body;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");
  if (!phase || isNaN(phase) || phase < 1) throw new ApiError(400, "Invalid phase");
  const revertCount = await approvalService.incrementRevertCount(projectId, phase);
  return res.status(200).json(new ApiResponse(200, { revertCount }, "Revert count incremented"));
});

export {
  compareAnswers,
  requestApproval,
  approve,
  revertToExecutor,
  getApprovalStatus,
  getRevertCount,
  incrementRevertCount,
};
