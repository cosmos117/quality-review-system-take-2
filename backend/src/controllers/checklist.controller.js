const isValidObjectId = (id) => /^[a-fA-F0-9]{24}$/.test(id);
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as checklistService from "../services/checklist.service.js";

const createChecklistForStage = asyncHandler(async (req, res) => {
  const { stageId } = req.params;
  if (!isValidObjectId(stageId)) throw new ApiError(400, "Invalid stageId");
  if (!req.body.checklist_name?.trim()) throw new ApiError(400, "checklist_name is required");
  const created_by = req.user?._id;
  if (!created_by) throw new ApiError(401, "Not authenticated");

  const checklist = await checklistService.createChecklistForStage(stageId, req.body, created_by);
  return res.status(201).json(new ApiResponse(201, checklist, "Checklist created successfully"));
});

const listChecklistsForStage = asyncHandler(async (req, res) => {
  const { stageId } = req.params;
  if (!isValidObjectId(stageId)) throw new ApiError(400, "Invalid stageId");

  const result = await checklistService.listChecklistsForStage(stageId, req.query);
  return res.status(200).json(result);
});

const getChecklistById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!isValidObjectId(id)) throw new ApiError(400, "Invalid checklist id");

  const checklist = await checklistService.getChecklistById(id);
  return res.status(200).json(new ApiResponse(200, checklist, "Checklist fetched successfully"));
});

const updateChecklist = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!isValidObjectId(id)) throw new ApiError(400, "Invalid checklist id");

  const checklist = await checklistService.updateChecklist(id, req.body);
  return res.status(200).json(new ApiResponse(200, checklist, "Checklist updated successfully"));
});

const deleteChecklist = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!isValidObjectId(id)) throw new ApiError(400, "Invalid checklist id");

  const deleted = await checklistService.deleteChecklist(id);
  return res.status(200).json(new ApiResponse(200, deleted, "Checklist deleted successfully"));
});

const submitChecklist = async (req, res) => {
  try {
    const checklist = await checklistService.submitChecklist(req.params.id, req.body.user_id);
    res.status(200).json({ message: "Checklist submitted for review successfully", checklist });
  } catch (err) {
    const status = err.statusCode || 500;
    res.status(status).json({ message: "Error submitting checklist", error: err.message });
  }
};

const approveChecklist = async (req, res) => {
  try {
    const checklist = await checklistService.approveChecklist(req.params.id, req.body.user_id);
    res.status(200).json({ message: "Checklist approved successfully", checklist });
  } catch (err) {
    const status = err.statusCode || 500;
    res.status(status).json({ message: "Error approving checklist", error: err.message });
  }
};

const requestChanges = async (req, res) => {
  try {
    const checklist = await checklistService.requestChanges(req.params.id, req.body.user_id, req.body.message);
    res.status(200).json({ message: "Changes requested successfully", checklist });
  } catch (err) {
    const status = err.statusCode || 500;
    res.status(status).json({ message: "Error requesting changes", error: err.message });
  }
};

const getChecklistHistory = async (req, res) => {
  try {
    const history = await checklistService.getChecklistHistory(req.params.id);
    if (!history.length) {
      return res.status(404).json({ message: "No history found for this checklist" });
    }
    res.status(200).json({ history });
  } catch (err) {
    res.status(500).json({ message: "Error fetching checklist history", error: err.message });
  }
};

export {
  listChecklistsForStage,
  getChecklistById,
  createChecklistForStage,
  updateChecklist,
  deleteChecklist,
  approveChecklist,
  submitChecklist,
  requestChanges,
  getChecklistHistory,
};
