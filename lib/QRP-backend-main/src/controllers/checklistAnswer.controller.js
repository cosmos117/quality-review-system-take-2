import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import Stage from "../models/stage.models.js";
import { ensureProjectChecklist } from "./projectChecklist.controller.js";

/**
 * Calculate defect count for a group based on executor and reviewer answers
 * Defect count increments when: executor and reviewer answers differ (mismatch)
 */
const calculateDefectCount = (group) => {
  let defectCount = 0;

  // Count defects in direct questions (any mismatch between executor and reviewer)
  for (const question of group.questions) {
    if (
      question.executorAnswer &&
      question.reviewerAnswer &&
      question.executorAnswer !== question.reviewerAnswer
    ) {
      defectCount++;
    }
  }

  // Count defects in section questions (any mismatch between executor and reviewer)
  for (const section of group.sections) {
    for (const question of section.questions) {
      if (
        question.executorAnswer &&
        question.reviewerAnswer &&
        question.executorAnswer !== question.reviewerAnswer
      ) {
        defectCount++;
      }
    }
  }

  return defectCount;
};

/**
 * GET /api/projects/:projectId/checklist-answers?phase=1&role=executor
 * Retrieves all checklist answers for a specific project, phase, and role
 */
const getChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.query;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role) {
    throw new ApiError(400, "Phase and role query parameters are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  // Find the stage for this phase
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    return res
      .status(200)
      .json(new ApiResponse(200, {}, "No stage found for this phase"));
  }

  // Get or create project checklist for this stage
  let checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    try {
      checklist = await ensureProjectChecklist({ projectId, stageDoc: stage });
    } catch (err) {
      return res
        .status(200)
        .json(
          new ApiResponse(200, {}, "No checklist found and failed to create"),
        );
    }
  }

  // Extract answers for the specified role into a map structure
  const answerMap = {};
  let totalAnswers = 0;

  checklist.groups.forEach((group, gIdx) => {
    // Direct questions in group
    group.questions.forEach((q, qIdx) => {
      // Use question _id as key (this is what frontend expects)
      const key = q._id ? q._id.toString() : q.text;
      if (normalizedRole === "executor") {
        answerMap[key] = {
          answer: q.executorAnswer,
          remark: q.executorRemark || "",
          images: q.executorImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.executor
            ? { id: q.answeredBy.executor }
            : null,
          answered_at: q.answeredAt?.executor || null,
        };
        if (q.executorAnswer !== null && q.executorAnswer !== undefined) {
          totalAnswers++;
        }
      } else {
        answerMap[key] = {
          answer: q.reviewerAnswer,
          remark: q.reviewerRemark || "",
          images: q.reviewerImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.reviewer
            ? { id: q.answeredBy.reviewer }
            : null,
          answered_at: q.answeredAt?.reviewer || null,
        };
        if (q.reviewerAnswer !== null && q.reviewerAnswer !== undefined) {
          totalAnswers++;
        }
      }
    });

    // Questions in sections
    group.sections.forEach((section, sIdx) => {
      section.questions.forEach((q, sqIdx) => {
        // Use question _id as key (this is what frontend expects)
        const key = q._id ? q._id.toString() : q.text;
        if (normalizedRole === "executor") {
          answerMap[key] = {
            answer: q.executorAnswer,
            remark: q.executorRemark || "",
            images: q.executorImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.executor
              ? { id: q.answeredBy.executor }
              : null,
            answered_at: q.answeredAt?.executor || null,
          };
          if (q.executorAnswer !== null && q.executorAnswer !== undefined) {
            totalAnswers++;
          }
        } else {
          answerMap[key] = {
            answer: q.reviewerAnswer,
            remark: q.reviewerRemark || "",
            images: q.reviewerImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.reviewer
              ? { id: q.answeredBy.reviewer }
              : null,
            answered_at: q.answeredAt?.reviewer || null,
          };
          if (q.reviewerAnswer !== null && q.reviewerAnswer !== undefined) {
            totalAnswers++;
          }
        }
      });
    });
  });

  return res
    .status(200)
    .json(
      new ApiResponse(200, answerMap, "Checklist answers fetched successfully"),
    );
});

/**
 * PUT /api/projects/:projectId/checklist-answers
 * Saves/updates checklist answers for a specific project, phase, and role
 * Body: { phase, role, answers: { "sub_question": { answer, remark, images, categoryId, severity }, ... } }
 */
const saveChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role, answers } = req.body;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role || !answers) {
    throw new ApiError(400, "Phase, role, and answers are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  const userId = req.user?._id || null;

  // answers should be an object: { "sub_question": { answer, remark, images }, ... }
  if (typeof answers !== "object" || Array.isArray(answers)) {
    throw new ApiError(400, "Answers must be an object with sub-question keys");
  }

  // Find the stage for this phase
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    throw new ApiError(404, "Stage not found for this phase");
  }

  // Get or create project checklist for this stage
  let checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    try {
      checklist = await ensureProjectChecklist({ projectId, stageDoc: stage });
    } catch (err) {
      throw new ApiError(500, `Failed to create checklist: ${err.message}`);
    }
  }

  const savedAnswers = [];
  let totalQuestions = 0;

  // Count total questions for debugging
  checklist.groups.forEach((group) => {
    totalQuestions += group.questions.length;
    group.sections.forEach((section) => {
      totalQuestions += section.questions.length;
    });
  });

  // Process each sub-question answer
  for (const [subQuestion, answerData] of Object.entries(answers)) {
    if (!answerData || typeof answerData !== "object") {
      continue; // Skip invalid entries
    }

    const { answer, remark, images, categoryId, severity } = answerData;

    // Find the question in the checklist (match by text OR by _id)
    let found = false;
    let groupIndex = 0;
    let questionPath = ""; // Track the path for markModified

    for (const group of checklist.groups) {
      // Search direct questions
      let qIndex = 0;
      for (const q of group.questions) {
        const matchByText = q.text === subQuestion;
        const matchById = q._id && q._id.toString() === subQuestion;

        if (matchByText || matchById) {
          questionPath = `groups.${groupIndex}.questions.${qIndex}`;
          if (normalizedRole === "executor") {
            if (answer !== undefined) q.executorAnswer = answer;
            if (remark !== undefined) q.executorRemark = remark || "";
            if (images !== undefined) {
              q.executorImages = Array.isArray(images) ? images : [];
              checklist.markModified(`${questionPath}.executorImages`); // Explicitly mark as modified
            }
            if (!q.answeredBy) q.answeredBy = {};
            q.answeredBy.executor = userId;
            if (!q.answeredAt) q.answeredAt = {};
            q.answeredAt.executor = new Date();
          } else {
            if (answer !== undefined) q.reviewerAnswer = answer;
            if (remark !== undefined) q.reviewerRemark = remark || "";
            if (images !== undefined) {
              q.reviewerImages = Array.isArray(images) ? images : [];
              checklist.markModified(`${questionPath}.reviewerImages`); // Explicitly mark as modified
            }
            if (!q.answeredBy) q.answeredBy = {};
            q.answeredBy.reviewer = userId;
            if (!q.answeredAt) q.answeredAt = {};
            q.answeredAt.reviewer = new Date();
          }
          if (categoryId !== undefined) q.categoryId = categoryId || "";
          if (severity !== undefined) q.severity = severity || "";
          found = true;
          savedAnswers.push({ question: subQuestion, updated: true });
          break;
        }
        qIndex++;
      }

      if (found) break;

      // Search questions in sections
      let sIndex = 0;
      for (const section of group.sections) {
        let sqIndex = 0;
        for (const q of section.questions) {
          const matchByText = q.text === subQuestion;
          const matchById = q._id && q._id.toString() === subQuestion;

          if (matchByText || matchById) {
            questionPath = `groups.${groupIndex}.sections.${sIndex}.questions.${sqIndex}`;
            if (normalizedRole === "executor") {
              if (answer !== undefined) q.executorAnswer = answer;
              if (remark !== undefined) q.executorRemark = remark || "";
              if (images !== undefined) {
                q.executorImages = Array.isArray(images) ? images : [];
                checklist.markModified(`${questionPath}.executorImages`); // Explicitly mark as modified
              }
              if (!q.answeredBy) q.answeredBy = {};
              q.answeredBy.executor = userId;
              if (!q.answeredAt) q.answeredAt = {};
              q.answeredAt.executor = new Date();
            } else {
              if (answer !== undefined) q.reviewerAnswer = answer;
              if (remark !== undefined) q.reviewerRemark = remark || "";
              if (images !== undefined) {
                q.reviewerImages = Array.isArray(images) ? images : [];
                checklist.markModified(`${questionPath}.reviewerImages`); // Explicitly mark as modified
              }
              if (!q.answeredBy) q.answeredBy = {};
              q.answeredBy.reviewer = userId;
              if (!q.answeredAt) q.answeredAt = {};
              q.answeredAt.reviewer = new Date();
            }
            if (categoryId !== undefined) q.categoryId = categoryId || "";
            if (severity !== undefined) q.severity = severity || "";
            found = true;
            savedAnswers.push({ question: subQuestion, updated: true });
            break;
          }
          sqIndex++;
        }
        if (found) break;
        sIndex++;
      }
      if (found) break;
      groupIndex++;
    }

    if (!found) {
      // Question not found, skip silently
    }
  }

  // Recalculate defect count for all groups after saving answers
  for (const group of checklist.groups) {
    const oldCount = group.defectCount || 0;
    group.defectCount = calculateDefectCount(group);
  }

  // Save the updated checklist
  // Mark the entire groups array as modified to ensure Mongoose saves nested changes
  checklist.markModified("groups");

  await checklist.save();

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        saved_count: savedAnswers.length,
        total_attempted: Object.keys(answers).length,
      },
      "Checklist answers saved successfully",
    ),
  );
});

/**
 * POST /api/projects/:projectId/checklist-answers/submit
 * Marks checklist answers as submitted for a specific project, phase, and role
 */
const submitChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.body;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role) {
    throw new ApiError(400, "Phase and role are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  // Get existing record to check if phase was reverted
  const existingRecord = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });

  const wasReverted = existingRecord?.status === "reverted_to_executor";

  // Build update object
  const updateFields = {
    [`${normalizedRole}_submitted`]: true,
    [`${normalizedRole}_submitted_at`]: new Date(),
  };

  // If executor is submitting after a revert, reset reviewer's submission
  // so reviewer can review again
  if (normalizedRole === "executor" && wasReverted) {
    updateFields.reviewer_submitted = false;
    updateFields.reviewer_submitted_at = null;
    updateFields.status = "pending"; // Reset status back to pending
  }

  // Find or create submission record in ChecklistApproval
  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    { $set: updateFields },
    { upsert: true, new: true },
  );

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        record,
        `${normalizedRole} checklist submitted successfully`,
      ),
    );
});

/**
 * GET /api/projects/:projectId/checklist-answers/submission-status
 * Gets submission status for a specific project, phase, and role
 */
const getSubmissionStatus = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.query;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role) {
    throw new ApiError(400, "Phase and role query parameters are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });

  const isSubmitted = record?.[`${normalizedRole}_submitted`] || false;
  const submittedAt = record?.[`${normalizedRole}_submitted_at`] || null;

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        is_submitted: isSubmitted,
        submitted_at: submittedAt,
      },
      "Submission status fetched successfully",
    ),
  );
});

export {
  getChecklistAnswers,
  saveChecklistAnswers,
  submitChecklistAnswers,
  getSubmissionStatus,
};
