import prisma from "../config/prisma.js";

const parseJsonField = (field) => {
    if (!field) return {};
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

async function fetchProjectData(projectId) {
  const stages = await prisma.stage.findMany({
    where: { project_id: projectId },
  });
  if (stages.length === 0) return { stages: [], checklists: [], checkpoints: [] };

  const stageIds = stages.map((s) => s.id);
  const checklists = await prisma.checklist.findMany({
    where: { stage_id: { in: stageIds } },
  });
  if (checklists.length === 0) return { stages, checklists: [], checkpoints: [] };

  const checklistIds = checklists.map((c) => c.id);
  const checkpoints = await prisma.checkpoint.findMany({
    where: { checklistId: { in: checklistIds } },
    select: { defect: true, checklistId: true },
  });

  return { stages, checklists, checkpoints };
}

export async function getProjectAnalysis(projectId) {
  const { stages, checklists, checkpoints } = await fetchProjectData(projectId);

  const emptyResult = {
    projectId,
    totalCheckpoints: 0,
    totalDefects: 0,
    defectRate: "0%",
    defectsByPhase: [],
    defectsByChecklist: [],
    categoryDistribution: [],
  };

  if (stages.length === 0 || checklists.length === 0) return emptyResult;

  const totalCheckpoints = checkpoints.length;
  const defectCheckpoints = checkpoints.filter((cp) => {
    const defect = parseJsonField(cp.defect);
    return defect.isDetected;
  });
  const totalDefects = defectCheckpoints.length;
  const defectRate =
    totalCheckpoints === 0
      ? "0%"
      : ((totalDefects / totalCheckpoints) * 100).toFixed(2) + "%";

  const checklistMap = new Map(checklists.map((c) => [c.id, c]));

  const defectsByPhase = {};
  stages.forEach((stage) => {
    defectsByPhase[stage.id] = {
      stageId: stage.id, stageName: stage.stage_name,
      totalCheckpoints: 0, defectCount: 0, defectRate: "0%",
    };
  });

  const defectsByChecklist = {};
  checklists.forEach((checklist) => {
    defectsByChecklist[checklist.id] = {
      checklistId: checklist.id, checklistName: checklist.checklist_name,
      totalCheckpoints: 0, defectCount: 0, defectRate: "0%",
    };
  });

  const categoryDistribution = {};

  checkpoints.forEach((checkpoint) => {
    const checklistId = checkpoint.checklistId;
    const checklist = checklistMap.get(checklistId);
    if (!checklist) return;

    const stageId = checklist.stage_id;
    if (defectsByPhase[stageId]) defectsByPhase[stageId].totalCheckpoints += 1;
    if (defectsByChecklist[checklistId]) defectsByChecklist[checklistId].totalCheckpoints += 1;

    const defect = parseJsonField(checkpoint.defect);

    if (defect.isDetected) {
      if (defectsByPhase[stageId]) defectsByPhase[stageId].defectCount += 1;
      if (defectsByChecklist[checklistId]) defectsByChecklist[checklistId].defectCount += 1;

      const categoryId = defect.categoryId || "Unassigned";
      categoryDistribution[categoryId] = (categoryDistribution[categoryId] || 0) + 1;
    }
  });

  Object.values(defectsByPhase).forEach((phase) => {
    phase.defectRate = phase.totalCheckpoints === 0
      ? "0%" : ((phase.defectCount / phase.totalCheckpoints) * 100).toFixed(2) + "%";
  });
  Object.values(defectsByChecklist).forEach((cl) => {
    cl.defectRate = cl.totalCheckpoints === 0
      ? "0%" : ((cl.defectCount / cl.totalCheckpoints) * 100).toFixed(2) + "%";
  });

  const phaseArray = Object.values(defectsByPhase).sort((a, b) => b.defectCount - a.defectCount);
  const checklistArray = Object.values(defectsByChecklist).sort((a, b) => b.defectCount - a.defectCount);
  const categoryArray = Object.entries(categoryDistribution)
    .map(([categoryId, count]) => ({
      categoryId, count,
      percentage: totalDefects === 0 ? "0.00%" : ((count / totalDefects) * 100).toFixed(2) + "%",
    }))
    .sort((a, b) => b.count - a.count);

  return {
    projectId,
    summary: { totalCheckpoints, totalDefects, defectRate },
    defectsByPhase: phaseArray,
    defectsByChecklist: checklistArray,
    categoryDistribution: categoryArray,
  };
}

export async function getDefectsPerPhase(projectId) {
  const { stages, checklists, checkpoints } = await fetchProjectData(projectId);

  return stages.map((stage) => {
    const stageChecklists = checklists.filter(
      (c) => c.stage_id === stage.id
    );
    const checklistIdsForStage = stageChecklists.map((c) => c.id);
    const checkpointsInStage = checkpoints.filter((cp) =>
      checklistIdsForStage.includes(cp.checklistId)
    );

    const totalCheckpoints = checkpointsInStage.length;
    const defectCount = checkpointsInStage.filter((cp) => parseJsonField(cp.defect).isDetected).length;

    return {
      stageId: stage.id, stageName: stage.stage_name, totalCheckpoints, defectCount,
      defectRate: totalCheckpoints === 0
        ? "0%" : ((defectCount / totalCheckpoints) * 100).toFixed(2) + "%",
    };
  });
}

export async function getDefectsPerChecklist(projectId) {
  const { stages, checklists, checkpoints } = await fetchProjectData(projectId);

  return checklists.map((checklist) => {
    const checkpointsInChecklist = checkpoints.filter(
      (cp) => cp.checklistId === checklist.id
    );
    const totalCheckpoints = checkpointsInChecklist.length;
    const defectCount = checkpointsInChecklist.filter((cp) => parseJsonField(cp.defect).isDetected).length;

    return {
      checklistId: checklist.id, checklistName: checklist.checklist_name,
      stageId: checklist.stage_id, totalCheckpoints, defectCount,
      defectRate: totalCheckpoints === 0
        ? "0%" : ((defectCount / totalCheckpoints) * 100).toFixed(2) + "%",
    };
  });
}

export async function getCategoryDistribution(projectId) {
  const { checkpoints } = await fetchProjectData(projectId);

  const defectedCheckpoints = checkpoints.filter((cp) => parseJsonField(cp.defect).isDetected);
  const totalDefects = defectedCheckpoints.length;

  if (totalDefects === 0) return { totalDefects: 0, distribution: [] };

  const categoryMap = {};
  defectedCheckpoints.forEach((checkpoint) => {
    const defect = parseJsonField(checkpoint.defect);
    const categoryId = defect.categoryId || "Unassigned";
    categoryMap[categoryId] = (categoryMap[categoryId] || 0) + 1;
  });

  const distribution = Object.entries(categoryMap)
    .map(([categoryId, count]) => ({
      categoryId, count,
      percentage: ((count / totalDefects) * 100).toFixed(2) + "%",
    }))
    .sort((a, b) => b.count - a.count);

  return { totalDefects, distribution };
}
