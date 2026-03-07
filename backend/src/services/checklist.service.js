import Checklist from "../models/checklist.models.js";
import ChecklistHistory from "../models/checklistTransaction.models.js";
import { ApiError } from "../utils/ApiError.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";

export async function createChecklistForStage(stageId, data, createdBy) {
  const { checklist_name, description, status, answers, defectCategory, defectSeverity, remark } = data;

  return Checklist.create({
    stage_id: stageId,
    created_by: createdBy,
    checklist_name,
    description,
    status,
    answers: answers || {},
    defectCategory: defectCategory || "",
    defectSeverity: defectSeverity || "",
    remark: remark || "",
  });
}

export async function listChecklistsForStage(stageId, query) {
  const { page, limit, skip } = parsePagination(query);
  const filter = { stage_id: stageId };
  const total = await Checklist.countDocuments(filter);

  let q = Checklist.find(filter).sort({ createdAt: 1 }).lean();
  if (limit) q = q.skip(skip).limit(limit);

  const checklists = await q;
  return paginatedResponse(checklists, total, { page, limit });
}

export async function getChecklistById(id) {
  const checklist = await Checklist.findById(id).lean();
  if (!checklist) throw new ApiError(404, "Checklist not found");
  return checklist;
}

export async function updateChecklist(id, data) {
  const { checklist_name, description, status, answers, defectCategory, defectSeverity, remark } = data;

  const update = {};
  if (typeof checklist_name === "string") update.checklist_name = checklist_name;
  if (typeof description === "string") update.description = description;
  if (typeof status === "string") update.status = status;
  if (answers && typeof answers === "object") update.answers = answers;
  if (typeof defectCategory === "string") update.defectCategory = defectCategory;
  if (typeof defectSeverity === "string") update.defectSeverity = defectSeverity;
  if (typeof remark === "string") update.remark = remark;

  if (Object.keys(update).length === 0) {
    throw new ApiError(400, "No valid fields provided to update");
  }

  const checklist = await Checklist.findByIdAndUpdate(id, { $set: update }, { new: true, runValidators: true }).lean();
  if (!checklist) throw new ApiError(404, "Checklist not found");
  return checklist;
}

export async function deleteChecklist(id) {
  const deleted = await Checklist.findByIdAndDelete(id);
  if (!deleted) throw new ApiError(404, "Checklist not found");
  return deleted;
}

export async function submitChecklist(checklistId, userId) {
  const checklist = await Checklist.findById(checklistId);
  if (!checklist) throw new ApiError(404, "Checklist not found");

  checklist.status = "pending";
  checklist.revision_number += 1;
  await checklist.save();

  await ChecklistHistory.create({
    checklist_id: checklist._id,
    user_id: userId,
    action_type: "SUBMITTED_FOR_REVIEW",
    description: `Checklist "${checklist.checklist_name}" was submitted for review.`,
  });

  return checklist;
}

export async function approveChecklist(checklistId, userId) {
  const checklist = await Checklist.findById(checklistId);
  if (!checklist) throw new ApiError(404, "Checklist not found");

  checklist.status = "approved";
  await checklist.save();

  await ChecklistHistory.create({
    checklist_id: checklist._id,
    user_id: userId,
    action_type: "APPROVED",
    description: `Checklist "${checklist.checklist_name}" was approved.`,
  });

  return checklist;
}

export async function requestChanges(checklistId, userId, message) {
  const checklist = await Checklist.findById(checklistId);
  if (!checklist) throw new ApiError(404, "Checklist not found");

  checklist.status = "changes_requested";
  await checklist.save();

  await ChecklistHistory.create({
    checklist_id: checklist._id,
    user_id: userId,
    action_type: "CHANGES_REQUESTED",
    description: message || `Changes were requested for checklist "${checklist.checklist_name}".`,
  });

  return checklist;
}

export async function getChecklistHistory(checklistId) {
  const history = await ChecklistHistory.find({ checklist_id: checklistId })
    .populate("user_id", "name email")
    .sort({ createdAt: 1 })
    .lean();

  return history;
}
