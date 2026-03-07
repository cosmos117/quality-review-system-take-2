import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import Stage from "../models/stage.models.js";
import Project from "../models/project.models.js";
import { accumulateDefectsForChecklist } from "./checklistAnswer.service.js";
import logger from "../utils/logger.js";
import { ApiError } from "../utils/ApiError.js";

function answersMatch(execAns, revAns) {
  const execKeys = Object.keys(execAns);
  const revKeys = Object.keys(revAns);
  const commonKeys = execKeys.filter((k) => revKeys.includes(k));
  if (commonKeys.length === 0) return true;
  for (const k of commonKeys) {
    const e = execAns[k] || {};
    const r = revAns[k] || {};
    if ((e.answer || null) !== (r.answer || null)) return false;
  }
  return true;
}

export const compareAnswers = async (projectId, phaseNum) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    return { match: true, stats: { exec_count: 0, rev_count: 0 } };
  }

  const checklist = await ProjectChecklist.findOne({
    projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    return { match: true, stats: { exec_count: 0, rev_count: 0 } };
  }

  const execMap = {};
  const revMap = {};
  let execCount = 0;
  let revCount = 0;

  checklist.groups.forEach((group) => {
    group.questions.forEach((q) => {
      const key = q.text;
      if (q.executorAnswer !== null && q.executorAnswer !== undefined) {
        execMap[key] = { answer: q.executorAnswer };
        execCount++;
      }
      if (q.reviewerAnswer !== null && q.reviewerAnswer !== undefined) {
        revMap[key] = { answer: q.reviewerAnswer };
        revCount++;
      }
    });

    group.sections.forEach((section) => {
      section.questions.forEach((q) => {
        const key = q.text;
        if (q.executorAnswer !== null && q.executorAnswer !== undefined) {
          execMap[key] = { answer: q.executorAnswer };
          execCount++;
        }
        if (q.reviewerAnswer !== null && q.reviewerAnswer !== undefined) {
          revMap[key] = { answer: q.reviewerAnswer };
          revCount++;
        }
      });
    });
  });

  const match = answersMatch(execMap, revMap);
  return { match, stats: { exec_count: execCount, rev_count: revCount } };
};

export const requestApproval = async (projectId, phaseNum, notes) => {
  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: { status: "pending", requested_at: new Date(), notes: notes || "" },
    },
    { new: true, upsert: true },
  );
  return record;
};

export const approve = async (projectId, phaseNum, userId) => {
  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: {
        status: "approved",
        decided_at: new Date(),
        decided_by: userId,
      },
    },
    { new: true, upsert: true },
  );

  const currentStageKey = `stage${phaseNum}`;
  await Stage.findOneAndUpdate(
    { project_id: projectId, stage_key: currentStageKey },
    { $set: { status: "completed" } },
  );

  const nextPhaseNum = phaseNum + 1;
  const nextStageKey = `stage${nextPhaseNum}`;
  const nextStage = await Stage.findOne({
    project_id: projectId,
    stage_key: nextStageKey,
  });

  if (nextStage) {
    await Stage.findByIdAndUpdate(nextStage._id, {
      $set: { status: "in_progress" },
    });
  } else {
    await Project.findByIdAndUpdate(projectId, { status: "completed" });
  }

  return record;
};

export const revertToExecutor = async (projectId, phaseNum, notes, userId) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    throw new ApiError(
      404,
      `Stage not found for project ${projectId}, phase ${phaseNum}`,
    );
  }

  const checklist = await ProjectChecklist.findOne({
    projectId,
    stageId: stage._id,
  });

  let totalNewDefects = 0;

  if (checklist) {
    totalNewDefects = accumulateDefectsForChecklist(checklist);

    logger.info(
      `Reviewer revert: Added ${totalNewDefects} new defects to phase ${phaseNum}`,
    );

    const approvalRecord = await ChecklistApproval.findOne({
      project_id: projectId,
      phase: phaseNum,
    });

    const newIteration = {
      iterationNumber: checklist.currentIteration || 1,
      groups: JSON.parse(JSON.stringify(checklist.groups)),
      revertedAt: new Date(),
      revertedBy: userId,
      revertNotes: notes || "",
      executorSubmittedAt: approvalRecord?.executor_submitted_at || null,
      reviewerSubmittedAt: approvalRecord?.reviewer_submitted_at || null,
    };

    checklist.iterations.push(newIteration);
    checklist.currentIteration = (checklist.currentIteration || 1) + 1;

    checklist.markModified("groups");
    await checklist.save();
  }

  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: {
        status: "reverted_to_executor",
        decided_at: new Date(),
        decided_by: userId,
        notes: notes || "",
        executor_submitted: false,
        executor_submitted_at: null,
      },
    },
    { new: true, upsert: true },
  );

  await Stage.findOneAndUpdate(
    { project_id: projectId, stage_key: stageKey },
    { $inc: { conflict_count: 1 } },
    { new: true, upsert: false },
  );

  const conflictCount = (stage?.conflict_count || 0) + 1;

  return {
    ...record.toObject(),
    conflict_count: conflictCount,
    iteration_saved: checklist?.currentIteration - 1 || null,
    defects_added: totalNewDefects,
  };
};

export const getApprovalStatus = async (projectId, phaseNum) => {
  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });
  return record;
};

export const getRevertCount = async (projectId, phaseNum) => {
  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });
  return record?.revertCount || 0;
};

export const incrementRevertCount = async (projectId, phase) => {
  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: parseInt(phase) },
    { $inc: { revertCount: 1 } },
    { new: true, upsert: true },
  );
  return record.revertCount;
};
