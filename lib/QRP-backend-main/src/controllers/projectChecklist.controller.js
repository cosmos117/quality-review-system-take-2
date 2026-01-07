import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";

const allowedExecutorAnswers = ["Yes", "No", "NA", null];
const allowedReviewerStatuses = ["Approved", "Rejected", null];

const inferStageKey = (stageName = "") => {
  const lower = stageName.toLowerCase();
  if (lower.includes("phase 1") || lower.includes("stage 1")) return "stage1";
  if (lower.includes("phase 2") || lower.includes("stage 2")) return "stage2";
  if (lower.includes("phase 3") || lower.includes("stage 3")) return "stage3";
  return null;
};

const mapTemplateToGroups = (stageTemplates = []) => {
  return stageTemplates.map((group) => ({
    groupName: (group?.text || "").trim(),
    questions: (group?.checkpoints || []).map((cp) => ({
      text: (cp?.text || "").trim(),
      executorAnswer: null,
      executorRemark: "",
      reviewerStatus: null,
      reviewerRemark: "",
    })),
    sections: (group?.sections || []).map((sec) => ({
      sectionName: (sec?.text || "").trim(),
      questions: (sec?.checkpoints || []).map((cp) => ({
        text: (cp?.text || "").trim(),
        executorAnswer: null,
        executorRemark: "",
        reviewerStatus: null,
        reviewerRemark: "",
      })),
    })),
  }));
};

const ensureProjectChecklist = async ({ projectId, stageDoc }) => {
  const existing = await ProjectChecklist.findOne({
    projectId,
    stageId: stageDoc._id,
  });
  if (existing) return existing;

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(404, "Template not found. Please create a template first.");
  }

  const stageKey = inferStageKey(stageDoc.stage_name) || "stage1";
  const groups = mapTemplateToGroups(template[stageKey] || []);

  const created = await ProjectChecklist.create({
    projectId,
    stageId: stageDoc._id,
    stage: stageDoc.stage_name,
    groups,
  });
  return created;
};

const findQuestionInGroup = (group, questionId) => {
  const direct = group.questions.id(questionId);
  if (direct) {
    return { question: direct, section: null };
  }
  for (const section of group.sections) {
    const nested = section.questions.id(questionId);
    if (nested) {
      return { question: nested, section };
    }
  }
  return { question: null, section: null };
};

const getProjectChecklist = asyncHandler(async (req, res) => {
  const { projectId, stageId } = req.params;

  if (!mongoose.isValidObjectId(projectId) || !mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }

  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId });
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  return res
    .status(200)
    .json(new ApiResponse(200, checklist, "Project checklist fetched successfully"));
});

const updateExecutorAnswer = asyncHandler(async (req, res) => {
  const { projectId, stageId, groupId, questionId } = req.params;
  const { answer, remark } = req.body;

  if (!mongoose.isValidObjectId(projectId) || !mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  if (!mongoose.isValidObjectId(groupId) || !mongoose.isValidObjectId(questionId)) {
    throw new ApiError(400, "Invalid groupId or questionId");
  }

  if (!allowedExecutorAnswers.includes(answer === undefined ? null : answer)) {
    throw new ApiError(400, "executorAnswer must be Yes, No, NA, or null");
  }

  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId });
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const group = checklist.groups.id(groupId);
  if (!group) {
    throw new ApiError(404, "Checklist group not found");
  }

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) {
    throw new ApiError(404, "Question not found in this group");
  }

  if (answer !== undefined) {
    question.executorAnswer = answer;
  }
  if (remark !== undefined) {
    question.executorRemark = remark || "";
  }

  await checklist.save();

  return res
    .status(200)
    .json(new ApiResponse(200, group.toObject(), "Executor response updated"));
});

const updateReviewerStatus = asyncHandler(async (req, res) => {
  const { projectId, stageId, groupId, questionId } = req.params;
  const { status, remark } = req.body;

  if (!mongoose.isValidObjectId(projectId) || !mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  if (!mongoose.isValidObjectId(groupId) || !mongoose.isValidObjectId(questionId)) {
    throw new ApiError(400, "Invalid groupId or questionId");
  }

  if (!allowedReviewerStatuses.includes(status === undefined ? null : status)) {
    throw new ApiError(400, "reviewerStatus must be Approved, Rejected, or null");
  }

  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId });
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const group = checklist.groups.id(groupId);
  if (!group) {
    throw new ApiError(404, "Checklist group not found");
  }

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) {
    throw new ApiError(404, "Question not found in this group");
  }

  if (status !== undefined) {
    question.reviewerStatus = status;
  }
  if (remark !== undefined) {
    question.reviewerRemark = remark || "";
  }

  await checklist.save();

  return res
    .status(200)
    .json(new ApiResponse(200, group.toObject(), "Reviewer decision updated"));
});

export {
  getProjectChecklist,
  updateExecutorAnswer,
  updateReviewerStatus,
  ensureProjectChecklist,
  mapTemplateToGroups,
  inferStageKey,
};
