const isValidObjectId = (id) => /^[a-fA-F0-9]{24}$/.test(id);
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as checklistAnswerService from "../services/checklistAnswer.service.js";

// Re-export so approval.controller.js import doesn't break
export const accumulateDefectsForChecklist = checklistAnswerService.accumulateDefectsForChecklist;

const getChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.query;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid project ID");
  if (!phase || !role) throw new ApiError(400, "Phase and role query parameters are required");
  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase number");
  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) throw new ApiError(400, "Role must be 'executor' or 'reviewer'");

  const data = await checklistAnswerService.getChecklistAnswers(projectId, phaseNum, normalizedRole);
  const message = Object.keys(data).length === 0 ? "No stage found for this phase" : "Checklist answers fetched successfully";
  return res.status(200).json(new ApiResponse(200, data, message));
});

const saveChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role, answers } = req.body;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid project ID");
  if (!phase || !role || !answers) throw new ApiError(400, "Phase, role, and answers are required");
  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase number");
  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  if (typeof answers !== "object" || Array.isArray(answers)) throw new ApiError(400, "Answers must be an object with sub-question keys");

  const userId = req.user?._id || null;
  const data = await checklistAnswerService.saveChecklistAnswers(projectId, phaseNum, normalizedRole, answers, userId);
  return res.status(200).json(new ApiResponse(200, data, "Checklist answers saved successfully"));
});

const submitChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.body;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid project ID");
  if (!phase || !role) throw new ApiError(400, "Phase and role are required");
  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase number");
  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) throw new ApiError(400, "Role must be 'executor' or 'reviewer'");

  const data = await checklistAnswerService.submitChecklistAnswers(projectId, phaseNum, normalizedRole);
  return res.status(200).json(new ApiResponse(200, data, `${normalizedRole} checklist submitted successfully`));
});

const getSubmissionStatus = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.query;
  if (!isValidObjectId(projectId)) throw new ApiError(400, "Invalid project ID");
  if (!phase || !role) throw new ApiError(400, "Phase and role query parameters are required");
  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase number");
  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) throw new ApiError(400, "Role must be 'executor' or 'reviewer'");

  const data = await checklistAnswerService.getSubmissionStatus(projectId, phaseNum, normalizedRole);
  return res.status(200).json(new ApiResponse(200, data, "Submission status fetched successfully"));
});

export {
  getChecklistAnswers,
  saveChecklistAnswers,
  submitChecklistAnswers,
  getSubmissionStatus,
};
