import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";
import { newId } from "../utils/newId.js";

export async function createChecklistForStage(stageId, data, createdBy) {
  const { checklist_name, description, status, answers, defectCategory, defectSeverity, remark } = data;

  return prisma.checklist.create({
    data: {
      id: newId(),
      stage_id: stageId,
      created_by: createdBy,
      checklist_name,
      description,
      status: status || "draft",
      answers: answers || {},
      defectCategory: defectCategory || "",
      defectSeverity: defectSeverity || "",
      remark: remark || "",
    }
  });
}

export async function listChecklistsForStage(stageId, query) {
  const { page, limit, skip } = parsePagination(query);
  const total = await prisma.checklist.count({ where: { stage_id: stageId } });

  const checklists = await prisma.checklist.findMany({
    where: { stage_id: stageId },
    orderBy: { createdAt: "asc" },
    ...(limit ? { skip, take: limit } : {})
  });

  return paginatedResponse(checklists, total, { page, limit });
}

export async function getChecklistById(id) {
  const checklist = await prisma.checklist.findUnique({ where: { id } });
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

  const checklist = await prisma.checklist.update({
    where: { id },
    data: update
  });
  if (!checklist) throw new ApiError(404, "Checklist not found");
  return checklist;
}

export async function deleteChecklist(id) {
  const checklist = await prisma.checklist.findUnique({ where: { id } });
  if (!checklist) throw new ApiError(404, "Checklist not found");
  
  await prisma.checklist.delete({ where: { id } });
  return checklist;
}

export async function submitChecklist(checklistId, userId) {
  const checklist = await prisma.checklist.findUnique({ where: { id: checklistId } });
  if (!checklist) throw new ApiError(404, "Checklist not found");

  const updatedChecklist = await prisma.checklist.update({
    where: { id: checklistId },
    data: {
      status: "pending",
      revision_number: { increment: 1 }
    }
  });

  await prisma.checklistTransaction.create({
    data: {
      id: newId(),
      checklist_id: checklist.id,
      user_id: userId,
      action_type: "SUBMITTED_FOR_REVIEW",
      description: `Checklist "${checklist.checklist_name}" was submitted for review.`
    }
  });

  return updatedChecklist;
}

export async function approveChecklist(checklistId, userId) {
  const checklist = await prisma.checklist.findUnique({ where: { id: checklistId } });
  if (!checklist) throw new ApiError(404, "Checklist not found");

  const updatedChecklist = await prisma.checklist.update({
    where: { id: checklistId },
    data: { status: "approved" }
  });

  await prisma.checklistTransaction.create({
    data: {
      id: newId(),
      checklist_id: checklist.id,
      user_id: userId,
      action_type: "APPROVED",
      description: `Checklist "${checklist.checklist_name}" was approved.`
    }
  });

  return updatedChecklist;
}

export async function requestChanges(checklistId, userId, message) {
  const checklist = await prisma.checklist.findUnique({ where: { id: checklistId } });
  if (!checklist) throw new ApiError(404, "Checklist not found");

  const updatedChecklist = await prisma.checklist.update({
    where: { id: checklistId },
    data: { status: "changes_requested" }
  });

  await prisma.checklistTransaction.create({
    data: {
      id: newId(),
      checklist_id: checklist.id,
      user_id: userId,
      action_type: "CHANGES_REQUESTED",
      description: message || `Changes were requested for checklist "${checklist.checklist_name}".`
    }
  });

  return updatedChecklist;
}

export async function getChecklistHistory(checklistId) {
  const history = await prisma.checklistTransaction.findMany({
    where: { checklist_id: checklistId },
    include: {
      user: { select: { id: true, name: true, email: true } }
    },
    orderBy: { createdAt: "asc" }
  });

  return history.map(h => ({
    ...h,
    user_id: h.user // Map back to Mongoose format
  }));
}
