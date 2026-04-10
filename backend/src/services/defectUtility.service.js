import logger from "../utils/logger.js";

const parseJsonField = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

export const areAnswersDifferent = (ans1, ans2) => {
  if (ans1 === ans2) return false;
  if (!ans1 || !ans2) return true;
  return ans1.trim().toLowerCase() !== ans2.trim().toLowerCase();
};

export const calculateDefectCount = (group) => {
  let defectCount = 0;
  const questions = group.questions || [];
  const sections = group.sections || [];

  for (const question of questions) {
    if (question.executorAnswer && question.reviewerAnswer && areAnswersDifferent(question.executorAnswer, question.reviewerAnswer)) {
      defectCount++;
    }
  }
  for (const section of sections) {
    for (const question of section.questions || []) {
      if (question.executorAnswer && question.reviewerAnswer && areAnswersDifferent(question.executorAnswer, question.reviewerAnswer)) {
        defectCount++;
      }
    }
  }
  return defectCount;
};

export const calculateCurrentMismatches = (groupsOrGroup) => {
  let totalQuestions = 0;
  let totalDefects = 0;

  const groups = Array.isArray(groupsOrGroup) ? groupsOrGroup : [groupsOrGroup];

  groups.forEach((group) => {
    if (group.questions && Array.isArray(group.questions)) {
      group.questions.forEach((q) => {
        totalQuestions++;
        const exAns = q.executorAnswer;
        const revAns = q.reviewerAnswer;
        if (exAns && revAns && areAnswersDifferent(exAns, revAns)) {
          totalDefects++;
        }
      });
    }
    if (group.sections && Array.isArray(group.sections)) {
      group.sections.forEach((section) => {
        if (section.questions && Array.isArray(section.questions)) {
          section.questions.forEach((q) => {
            totalQuestions++;
            const exAns = q.executorAnswer;
            const revAns = q.reviewerAnswer;
            if (exAns && revAns && areAnswersDifferent(exAns, revAns)) {
              totalDefects++;
            }
          });
        }
      });
    }
  });

  return { totalQuestions, totalDefects };
};

/**
 * Calculates iteration defect rates and total cumulative defects.
 * @param {Array} iterations - The iterations array from ProjectChecklist
 * @param {Array} currentGroups - The current live groups from ProjectChecklist
 * @param {Object} checklist - The full checklist object (optional fallback)
 */
export const calculateIterationDefectRates = (iterations, currentGroups) => {
  const safeIterations = Array.isArray(iterations) ? iterations : [];
  const safeGroups = Array.isArray(currentGroups) ? currentGroups : [];

  const iterationsWithRates = [];
  let cumulativeDefects = 0;

  // Process historical iterations
  for (let i = 0; i < safeIterations.length; i++) {
    const iter = safeIterations[i];
    const groups = parseJsonField(iter.groups);
    const stats = calculateCurrentMismatches(groups);
    
    // In historical iterations, these were the "new" defects that caused the revert
    const newDefectsInIteration = stats.totalDefects;
    cumulativeDefects += newDefectsInIteration;

    const defectRate = stats.totalQuestions > 0
      ? parseFloat(((newDefectsInIteration / stats.totalQuestions) * 100).toFixed(2))
      : 0;

    iterationsWithRates.push({
      iterationNumber: iter.iterationNumber || (i + 1),
      totalQuestions: stats.totalQuestions,
      totalDefects: newDefectsInIteration,
      cumulativeDefects: cumulativeDefects, // Track cumulative for overall rate
      defectRate,
      revertedAt: iter.revertedAt,
      revertNotes: iter.revertNotes,
    });
  }

  // Calculate current iteration stats
  const currentMismatchStats = calculateCurrentMismatches(safeGroups);
  const currentDefectRate = currentMismatchStats.totalQuestions > 0
    ? parseFloat(((currentMismatchStats.totalDefects / currentMismatchStats.totalQuestions) * 100).toFixed(2))
    : 0;

  return {
    iterations: iterationsWithRates,
    current: {
      iterationNumber: (safeIterations.length + 1),
      totalQuestions: currentMismatchStats.totalQuestions,
      totalDefects: currentMismatchStats.totalDefects,
      defectRate: currentDefectRate,
    },
    totalCumulativeDefects: cumulativeDefects, // Excludes current mismatches
  };
};

export const accumulateDefectsForChecklistGroups = (groups) => {
  let totalNewDefects = 0;
  for (const group of groups) {
    const currentMismatches = calculateCurrentMismatches(group);
    const existingDefectCount = group.defectCount || 0;
    group.defectCount = existingDefectCount + currentMismatches.totalDefects;
    totalNewDefects += currentMismatches.totalDefects;
  }
  return totalNewDefects;
};
