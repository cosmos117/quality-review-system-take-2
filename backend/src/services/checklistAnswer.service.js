import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import Stage from "../models/stage.models.js";
import { ensureProjectChecklist } from "./projectChecklist.service.js";
import { ApiError } from "../utils/ApiError.js";
import logger from "../utils/logger.js";

const calculateCurrentMismatches = (group) => {
  let mismatchCount = 0;
  for (const question of group.questions) {
    if (
      question.executorAnswer &&
      question.reviewerAnswer &&
      question.executorAnswer !== question.reviewerAnswer
    ) {
      mismatchCount++;
    }
  }
  for (const section of group.sections) {
    for (const question of section.questions) {
      if (
        question.executorAnswer &&
        question.reviewerAnswer &&
        question.executorAnswer !== question.reviewerAnswer
      ) {
        mismatchCount++;
      }
    }
  }
  return mismatchCount;
};

/**
 * Accumulate defects for all groups in a checklist.
 * Adds current mismatches to existing defect count (incremental only, never decrements).
 */
export const accumulateDefectsForChecklist = (checklist) => {
  let totalNewDefects = 0;
  for (const group of checklist.groups) {
    const currentMismatches = calculateCurrentMismatches(group);
    const existingDefectCount = group.defectCount || 0;
    group.defectCount = existingDefectCount + currentMismatches;
    totalNewDefects += currentMismatches;
  }
  return totalNewDefects;
};

export const getChecklistAnswers = async (projectId, phaseNum, normalizedRole) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  }).select("_id stage_name").lean();

  if (!stage) {
    return {};
  }

  let checklist = await ProjectChecklist.findOne({
    projectId,
    stageId: stage._id,
  }).lean();

  if (!checklist) {
    try {
      checklist = await ensureProjectChecklist({ projectId, stageDoc: stage });
    } catch (_) {
      return {};
    }
  }

  const answerMap = {};

  checklist.groups.forEach((group) => {
    group.questions.forEach((q) => {
      const key = q._id ? q._id.toString() : q.text;
      if (normalizedRole === "executor") {
        answerMap[key] = {
          answer: q.executorAnswer,
          remark: q.executorRemark || "",
          images: q.executorImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.executor ? { id: q.answeredBy.executor } : null,
          answered_at: q.answeredAt?.executor || null,
        };
      } else {
        answerMap[key] = {
          answer: q.reviewerAnswer,
          remark: q.reviewerRemark || "",
          images: q.reviewerImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.reviewer ? { id: q.answeredBy.reviewer } : null,
          answered_at: q.answeredAt?.reviewer || null,
        };
      }
    });

    group.sections.forEach((section) => {
      section.questions.forEach((q) => {
        const key = q._id ? q._id.toString() : q.text;
        if (normalizedRole === "executor") {
          answerMap[key] = {
            answer: q.executorAnswer,
            remark: q.executorRemark || "",
            images: q.executorImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.executor ? { id: q.answeredBy.executor } : null,
            answered_at: q.answeredAt?.executor || null,
          };
        } else {
          answerMap[key] = {
            answer: q.reviewerAnswer,
            remark: q.reviewerRemark || "",
            images: q.reviewerImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.reviewer ? { id: q.answeredBy.reviewer } : null,
            answered_at: q.answeredAt?.reviewer || null,
          };
        }
      });
    });
  });

  return answerMap;
};

export const saveChecklistAnswers = async (projectId, phaseNum, normalizedRole, answers, userId) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  }).select("_id stage_name").lean();

  if (!stage) {
    throw new ApiError(404, "Stage not found for this phase");
  }

  let checklist = await ProjectChecklist.findOne({
    projectId,
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

  for (const [subQuestion, answerData] of Object.entries(answers)) {
    if (!answerData || typeof answerData !== "object") continue;

    const { answer, remark, images, categoryId, severity } = answerData;

    let found = false;
    let groupIndex = 0;

    for (const group of checklist.groups) {
      let qIndex = 0;
      for (const q of group.questions) {
        const matchByText = q.text === subQuestion;
        const matchById = q._id && q._id.toString() === subQuestion;

        if (matchByText || matchById) {
          const questionPath = `groups.${groupIndex}.questions.${qIndex}`;
          if (normalizedRole === "executor") {
            if (answer !== undefined) q.executorAnswer = answer;
            if (remark !== undefined) q.executorRemark = remark || "";
            if (images !== undefined) {
              q.executorImages = Array.isArray(images) ? images : [];
              checklist.markModified(`${questionPath}.executorImages`);
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
              checklist.markModified(`${questionPath}.reviewerImages`);
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

      let sIndex = 0;
      for (const section of group.sections) {
        let sqIndex = 0;
        for (const q of section.questions) {
          const matchByText = q.text === subQuestion;
          const matchById = q._id && q._id.toString() === subQuestion;

          if (matchByText || matchById) {
            const questionPath = `groups.${groupIndex}.sections.${sIndex}.questions.${sqIndex}`;
            if (normalizedRole === "executor") {
              if (answer !== undefined) q.executorAnswer = answer;
              if (remark !== undefined) q.executorRemark = remark || "";
              if (images !== undefined) {
                q.executorImages = Array.isArray(images) ? images : [];
                checklist.markModified(`${questionPath}.executorImages`);
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
                checklist.markModified(`${questionPath}.reviewerImages`);
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
  }

  checklist.markModified("groups");
  await checklist.save();

  return {
    saved_count: savedAnswers.length,
    total_attempted: Object.keys(answers).length,
  };
};

export const submitChecklistAnswers = async (projectId, phaseNum, normalizedRole) => {
  const stageKey = `stage${phaseNum}`;
  const [existingRecord, stage] = await Promise.all([
    ChecklistApproval.findOne({
      project_id: projectId,
      phase: phaseNum,
    }).lean(),
    Stage.findOne({
      project_id: projectId,
      stage_key: stageKey,
    }).select("_id").lean(),
  ]);

  const wasReverted = existingRecord?.status === "reverted_to_executor";
  let totalNewDefects = 0;

  if (stage) {
    const checklist = await ProjectChecklist.findOne({
      projectId,
      stageId: stage._id,
    });

    if (checklist) {
      let shouldAccumulate = false;

      if (normalizedRole === "reviewer") {
        shouldAccumulate = true;
      } else if (normalizedRole === "executor") {
        const reviewerHasAnswered = existingRecord?.reviewer_submitted === true;
        shouldAccumulate = reviewerHasAnswered;
      }

      if (shouldAccumulate) {
        totalNewDefects = accumulateDefectsForChecklist(checklist);
        checklist.markModified("groups");
        await checklist.save();

        logger.info(
          `${normalizedRole.charAt(0).toUpperCase() + normalizedRole.slice(1)} submission: Added ${totalNewDefects} new defects to phase ${phaseNum}`,
        );
      }
    }
  }

  const updateFields = {
    [`${normalizedRole}_submitted`]: true,
    [`${normalizedRole}_submitted_at`]: new Date(),
  };

  if (normalizedRole === "executor" && wasReverted) {
    updateFields.reviewer_submitted = false;
    updateFields.reviewer_submitted_at = null;
    updateFields.status = "pending";
  }

  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    { $set: updateFields },
    { upsert: true, new: true },
  );

  const responseData = { ...record.toObject() };
  if (totalNewDefects > 0) {
    responseData.defects_added = totalNewDefects;
  }

  return responseData;
};

export const getSubmissionStatus = async (projectId, phaseNum, normalizedRole) => {
  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  }).lean();

  return {
    is_submitted: record?.[`${normalizedRole}_submitted`] || false,
    submitted_at: record?.[`${normalizedRole}_submitted_at`] || null,
  };
};
