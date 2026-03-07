import Checkpoint from "../models/checkpoint.models.js";
import Checklist from "../models/checklist.models.js";
import Stage from "../models/stage.models.js";

async function fetchProjectData(projectId) {
  const stages = await Stage.find({ project_id: projectId }).lean();
  if (stages.length === 0) return { stages: [], checklists: [], checkpoints: [] };

  const stageIds = stages.map((s) => s._id);
  const checklists = await Checklist.find({ stage_id: { $in: stageIds } }).lean();
  if (checklists.length === 0) return { stages, checklists: [], checkpoints: [] };

  const checklistIds = checklists.map((c) => c._id);
  const checkpoints = await Checkpoint.find({ checklistId: { $in: checklistIds } })
    .select("defect checklistId")
    .lean();

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
  const defectCheckpoints = checkpoints.filter((cp) => cp.defect.isDetected);
  const totalDefects = defectCheckpoints.length;
  const defectRate =
    totalCheckpoints === 0
      ? "0%"
      : ((totalDefects / totalCheckpoints) * 100).toFixed(2) + "%";

  const checklistMap = new Map(checklists.map((c) => [c._id.toString(), c]));

  const defectsByPhase = {};
  stages.forEach((stage) => {
    defectsByPhase[stage._id.toString()] = {
      stageId: stage._id, stageName: stage.stage_name,
      totalCheckpoints: 0, defectCount: 0, defectRate: "0%",
    };
  });

  const defectsByChecklist = {};
  checklists.forEach((checklist) => {
    defectsByChecklist[checklist._id.toString()] = {
      checklistId: checklist._id, checklistName: checklist.checklist_name,
      totalCheckpoints: 0, defectCount: 0, defectRate: "0%",
    };
  });

  const categoryDistribution = {};

  checkpoints.forEach((checkpoint) => {
    const checklistId = checkpoint.checklistId.toString();
    const checklist = checklistMap.get(checklistId);
    if (!checklist) return;

    const stageId = checklist.stage_id.toString();
    if (defectsByPhase[stageId]) defectsByPhase[stageId].totalCheckpoints += 1;
    if (defectsByChecklist[checklistId]) defectsByChecklist[checklistId].totalCheckpoints += 1;

    if (checkpoint.defect.isDetected) {
      if (defectsByPhase[stageId]) defectsByPhase[stageId].defectCount += 1;
      if (defectsByChecklist[checklistId]) defectsByChecklist[checklistId].defectCount += 1;

      const categoryId = checkpoint.defect.categoryId || "Unassigned";
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
      percentage: ((count / totalDefects) * 100).toFixed(2) + "%",
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
      (c) => c.stage_id.toString() === stage._id.toString()
    );
    const checklistIdsForStage = stageChecklists.map((c) => c._id.toString());
    const checkpointsInStage = checkpoints.filter((cp) =>
      checklistIdsForStage.includes(cp.checklistId.toString())
    );

    const totalCheckpoints = checkpointsInStage.length;
    const defectCount = checkpointsInStage.filter((cp) => cp.defect.isDetected).length;

    return {
      stageId: stage._id, stageName: stage.stage_name, totalCheckpoints, defectCount,
      defectRate: totalCheckpoints === 0
        ? "0%" : ((defectCount / totalCheckpoints) * 100).toFixed(2) + "%",
    };
  });
}

export async function getDefectsPerChecklist(projectId) {
  const { stages, checklists, checkpoints } = await fetchProjectData(projectId);

  return checklists.map((checklist) => {
    const checkpointsInChecklist = checkpoints.filter(
      (cp) => cp.checklistId.toString() === checklist._id.toString()
    );
    const totalCheckpoints = checkpointsInChecklist.length;
    const defectCount = checkpointsInChecklist.filter((cp) => cp.defect.isDetected).length;

    return {
      checklistId: checklist._id, checklistName: checklist.checklist_name,
      stageId: checklist.stage_id, totalCheckpoints, defectCount,
      defectRate: totalCheckpoints === 0
        ? "0%" : ((defectCount / totalCheckpoints) * 100).toFixed(2) + "%",
    };
  });
}

export async function getCategoryDistribution(projectId) {
  const { checkpoints } = await fetchProjectData(projectId);

  const defectedCheckpoints = checkpoints.filter((cp) => cp.defect.isDetected);
  const totalDefects = defectedCheckpoints.length;

  if (totalDefects === 0) return { totalDefects: 0, distribution: [] };

  const categoryMap = {};
  defectedCheckpoints.forEach((checkpoint) => {
    const categoryId = checkpoint.defect.categoryId || "Unassigned";
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
