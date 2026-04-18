import prisma from "../config/prisma.js";

const parseJsonField = (field, fallback = []) => {
  if (field === null || field === undefined) return fallback;
  if (typeof field === "string") {
    try {
      return JSON.parse(field);
    } catch {
      return fallback;
    }
  }
  return field;
};

const toArray = (value) => (Array.isArray(value) ? value : []);

const normalize = (value) => (value || "").toString().trim().toLowerCase();

const collectQuestionsFromGroup = (group) => {
  const directQuestions = toArray(group?.questions);
  const sectionQuestions = toArray(group?.sections).flatMap((section) =>
    toArray(section?.questions),
  );
  return [...directQuestions, ...sectionQuestions];
};

const isDefectQuestion = (question) => {
  const categoryId = normalize(question?.categoryId);
  if (categoryId) return true;

  const reviewerStatus = normalize(question?.reviewerStatus);
  if (reviewerStatus === "rejected") return true;

  const executorAnswer = normalize(question?.executorAnswer);
  const reviewerAnswer = normalize(question?.reviewerAnswer);
  if (executorAnswer && reviewerAnswer && executorAnswer !== reviewerAnswer) {
    return true;
  }

  return false;
};

async function fetchProjectData(projectId) {
  const stages = await prisma.stage.findMany({
    where: { project_id: projectId },
  });

  const stageIds = stages.map((stage) => stage.id);
  const stageById = new Map(stages.map((stage) => [stage.id, stage]));

  const projectChecklists = await prisma.projectChecklist.findMany({
    where: {
      projectId,
      ...(stageIds.length > 0 ? { stageId: { in: stageIds } } : {}),
    },
    select: {
      id: true,
      stageId: true,
      stage: true,
      groups: true,
    },
  });

  return { stages, stageById, projectChecklists };
}

function buildMetrics(stages, stageById, projectChecklists) {
  const phasesMap = new Map(
    stages.map((stage) => [
      stage.id,
      {
        stageId: stage.id,
        stageName: stage.stage_name,
        totalCheckpoints: 0,
        defectCount: 0,
        defectRate: "0%",
      },
    ]),
  );

  const checklistsMap = new Map();
  const categoryCounts = {};

  let totalCheckpoints = 0;
  let totalDefects = 0;

  for (const projectChecklist of projectChecklists) {
    const stageInfo = stageById.get(projectChecklist.stageId);
    const stageId = projectChecklist.stageId;

    if (!phasesMap.has(stageId)) {
      phasesMap.set(stageId, {
        stageId,
        stageName:
          stageInfo?.stage_name ||
          projectChecklist.stage ||
          `Stage ${stageId.toString().slice(-4)}`,
        totalCheckpoints: 0,
        defectCount: 0,
        defectRate: "0%",
      });
    }

    const phaseStat = phasesMap.get(stageId);
    const groups = toArray(parseJsonField(projectChecklist.groups));

    groups.forEach((group, groupIndex) => {
      const checklistId = `${projectChecklist.id}:${group?._id || groupIndex}`;
      const checklistName =
        (group?.groupName || "").toString().trim() || `Group ${groupIndex + 1}`;

      if (!checklistsMap.has(checklistId)) {
        checklistsMap.set(checklistId, {
          checklistId,
          checklistName,
          stageId,
          totalCheckpoints: 0,
          defectCount: 0,
          defectRate: "0%",
        });
      }

      const checklistStat = checklistsMap.get(checklistId);
      const questions = collectQuestionsFromGroup(group);

      for (const question of questions) {
        totalCheckpoints += 1;
        phaseStat.totalCheckpoints += 1;
        checklistStat.totalCheckpoints += 1;

        if (!isDefectQuestion(question)) continue;

        totalDefects += 1;
        phaseStat.defectCount += 1;
        checklistStat.defectCount += 1;

        const categoryId =
          (question?.categoryId || "").toString().trim() || "Unassigned";
        categoryCounts[categoryId] = (categoryCounts[categoryId] || 0) + 1;
      }
    });
  }

  const overallDefectRate =
    totalCheckpoints === 0
      ? "0%"
      : ((totalDefects / totalCheckpoints) * 100).toFixed(2) + "%";

  const defectsByPhase = Array.from(phasesMap.values())
    .map((phase) => ({
      ...phase,
      defectRate:
        phase.totalCheckpoints === 0
          ? "0%"
          : ((phase.defectCount / phase.totalCheckpoints) * 100).toFixed(2) +
            "%",
    }))
    .sort((a, b) => b.defectCount - a.defectCount);

  const defectsByChecklist = Array.from(checklistsMap.values())
    .map((checklist) => ({
      ...checklist,
      defectRate:
        checklist.totalCheckpoints === 0
          ? "0%"
          : (
              (checklist.defectCount / checklist.totalCheckpoints) *
              100
            ).toFixed(2) + "%",
    }))
    .sort((a, b) => b.defectCount - a.defectCount);

  const categoryDistribution = Object.entries(categoryCounts)
    .map(([categoryId, count]) => ({
      categoryId,
      count,
      percentage:
        totalDefects === 0
          ? "0.00%"
          : ((count / totalDefects) * 100).toFixed(2) + "%",
    }))
    .sort((a, b) => b.count - a.count);

  return {
    totalCheckpoints,
    totalDefects,
    overallDefectRate,
    defectsByPhase,
    defectsByChecklist,
    categoryDistribution,
  };
}

export async function getProjectAnalysis(projectId) {
  const { stages, stageById, projectChecklists } =
    await fetchProjectData(projectId);

  const emptyResult = {
    projectId,
    totalCheckpoints: 0,
    totalDefects: 0,
    defectRate: "0%",
    defectsByPhase: [],
    defectsByChecklist: [],
    categoryDistribution: [],
  };

  if (stages.length === 0 && projectChecklists.length === 0) return emptyResult;

  const metrics = buildMetrics(stages, stageById, projectChecklists);

  return {
    projectId,
    summary: {
      totalCheckpoints: metrics.totalCheckpoints,
      totalDefects: metrics.totalDefects,
      defectRate: metrics.overallDefectRate,
    },
    defectsByPhase: metrics.defectsByPhase,
    defectsByChecklist: metrics.defectsByChecklist,
    categoryDistribution: metrics.categoryDistribution,
  };
}

export async function getDefectsPerPhase(projectId) {
  const { stages, stageById, projectChecklists } =
    await fetchProjectData(projectId);
  const metrics = buildMetrics(stages, stageById, projectChecklists);
  return metrics.defectsByPhase;
}

export async function getDefectsPerChecklist(projectId) {
  const { stages, stageById, projectChecklists } =
    await fetchProjectData(projectId);
  const metrics = buildMetrics(stages, stageById, projectChecklists);
  return metrics.defectsByChecklist;
}

export async function getCategoryDistribution(projectId) {
  const { stages, stageById, projectChecklists } =
    await fetchProjectData(projectId);
  const metrics = buildMetrics(stages, stageById, projectChecklists);

  return {
    totalDefects: metrics.totalDefects,
    distribution: metrics.categoryDistribution,
  };
}
