import prisma from "../config/prisma.js";
import { accumulateDefectsForChecklistGroups } from "./defectUtility.service.js";
import logger from "../utils/logger.js";
import { ApiError } from "../utils/ApiError.js";
import { newId } from "../utils/newId.js";

const parseJsonField = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

import { areAnswersDifferent } from "./defectUtility.service.js";

function answersMatch(execAns, revAns) {
  const execKeys = Object.keys(execAns);
  const revKeys = Object.keys(revAns);
  const commonKeys = execKeys.filter((k) => revKeys.includes(k));
  if (commonKeys.length === 0) return true;
  for (const k of commonKeys) {
    const e = execAns[k] || {};
    const r = revAns[k] || {};
    // Use normalized comparison from utility
    if (areAnswersDifferent(e.answer, r.answer)) return false;
  }
  return true;
}

export const compareAnswers = async (projectId, phaseNum) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true },
  });

  if (!stage) {
    return { match: true, stats: { exec_count: 0, rev_count: 0 } };
  }

  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } }
  });

  if (!checklist) {
    return { match: true, stats: { exec_count: 0, rev_count: 0 } };
  }

  const execMap = {};
  const revMap = {};
  let execCount = 0;
  let revCount = 0;

  const groups = parseJsonField(checklist.groups);

  groups.forEach((group) => {
    (group.questions || []).forEach((q) => {
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

    (group.sections || []).forEach((section) => {
      (section.questions || []).forEach((q) => {
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
  const updateFields = {
    status: "pending", 
    requested_at: new Date(), 
    notes: notes || ""
  };
  
  const record = await prisma.checklistApproval.upsert({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
    update: updateFields,
    create: {
      id: newId(),
      project_id: projectId,
      phase: phaseNum,
      status: "pending",
      ...updateFields
    }
  });
  
  return record;
};

export const approve = async (projectId, phaseNum, userId) => {
  const record = await prisma.checklistApproval.upsert({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
    update: {
      status: "approved",
      decided_at: new Date(),
      decided_by: userId,
    },
    create: {
      id: newId(),
      project_id: projectId,
      phase: phaseNum,
      status: "approved",
      decided_at: new Date(),
      decided_by: userId,
    }
  });

  const currentStageKey = `stage${phaseNum}`;
  await prisma.stage.updateMany({
    where: { project_id: projectId, stage_key: currentStageKey },
    data: { status: "completed" }
  });

  const nextPhaseNum = phaseNum + 1;
  const nextStageKey = `stage${nextPhaseNum}`;
  const nextStage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: nextStageKey },
    select: { id: true }
  });

  if (nextStage) {
    await prisma.stage.update({
      where: { id: nextStage.id },
      data: { status: "in_progress" }
    });
  } else {
    await prisma.project.update({
      where: { id: projectId },
      data: { status: "completed" }
    });
  }

  return record;
};

export const revertToExecutor = async (projectId, phaseNum, notes, userId) => {
  const stageKey = `stage${phaseNum}`;
  const stage = await prisma.stage.findFirst({
    where: { project_id: projectId, stage_key: stageKey },
    select: { id: true, conflict_count: true }
  });

  if (!stage) {
    throw new ApiError(404, `Stage not found for project ${projectId}, phase ${phaseNum}`);
  }

  const checklist = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId, stageId: stage.id } }
  });

  let totalNewDefects = 0;
  let iterationSaved = null;

  if (checklist) {
    const groups = parseJsonField(checklist.groups);
    const iterations = parseJsonField(checklist.iterations) || [];
    
    totalNewDefects = accumulateDefectsForChecklistGroups(groups);

    logger.info(`Reviewer revert: Added ${totalNewDefects} new defects to phase ${phaseNum}`);

    const approvalRecord = await prisma.checklistApproval.findUnique({
      where: { project_id_phase: { project_id: projectId, phase: phaseNum } }
    });

    const newIteration = {
      iterationNumber: checklist.currentIteration || 1,
      groups: JSON.parse(JSON.stringify(groups)),
      revertedAt: new Date().toISOString(),
      revertedBy: userId,
      revertNotes: notes || "",
      executorSubmittedAt: approvalRecord?.executor_submitted_at || null,
      reviewerSubmittedAt: approvalRecord?.reviewer_submitted_at || null,
    };

    iterations.push(newIteration);
    const updatedCurrentIteration = (checklist.currentIteration || 1) + 1;
    iterationSaved = checklist.currentIteration;

    await prisma.projectChecklist.update({
      where: { id: checklist.id },
      data: {
        groups,
        iterations,
        currentIteration: updatedCurrentIteration
      }
    });
  }

  const updateFields = {
    status: "reverted_to_executor",
    decided_at: new Date(),
    decided_by: userId,
    notes: notes || "",
    executor_submitted: false,
    executor_submitted_at: null,
  };

  const record = await prisma.checklistApproval.upsert({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
    update: { ...updateFields, revertCount: { increment: 1 } },
    create: {
      id: newId(),
      project_id: projectId,
      phase: phaseNum,
      revertCount: 1,
      ...updateFields
    }
  });

  const updatedStage = await prisma.stage.update({
    where: { id: stage.id },
    data: { conflict_count: { increment: 1 } }
  });

  return {
    ...record,
    conflict_count: updatedStage.conflict_count,
    iteration_saved: iterationSaved,
    defects_added: totalNewDefects,
  };
};

export const getApprovalStatus = async (projectId, phaseNum) => {
  return await prisma.checklistApproval.findUnique({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } }
  });
};

export const getRevertCount = async (projectId, phaseNum) => {
  const record = await prisma.checklistApproval.findUnique({
    where: { project_id_phase: { project_id: projectId, phase: phaseNum } },
    select: { revertCount: true }
  });
  return record?.revertCount || 0;
};

export const incrementRevertCount = async (projectId, phase) => {
  const record = await prisma.checklistApproval.upsert({
    where: { project_id_phase: { project_id: projectId, phase: parseInt(phase) } },
    update: { revertCount: { increment: 1 } },
    create: {
      id: newId(),
      project_id: projectId,
      phase: parseInt(phase),
      revertCount: 1,
      status: "pending"
    }
  });
  return record.revertCount;
};
