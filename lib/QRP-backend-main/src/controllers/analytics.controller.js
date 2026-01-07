import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Checkpoint from "../models/checkpoint.models.js";
import Checklist from "../models/checklist.models.js";
import Stage from "../models/stage.models.js";

/**
 * GET DEFECT ANALYSIS FOR A PROJECT
 * GET /api/v1/projects/:projectId/analysis
 * Returns overall defect statistics for a project
 */
export const getProjectAnalysis = asyncHandler(async (req, res) => {
  const { projectId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  // Get all stages for the project
  const stages = await Stage.find({ project_id: projectId });
  if (stages.length === 0) {
    return res.status(200).json(
      new ApiResponse(
        200,
        {
          projectId,
          totalCheckpoints: 0,
          totalDefects: 0,
          defectRate: "0%",
          defectsByPhase: [],
          defectsByChecklist: [],
          categoryDistribution: [],
        },
        "No stages found for this project"
      )
    );
  }

  // Get all checklists for these stages
  const stageIds = stages.map((s) => s._id);
  const checklists = await Checklist.find({ stage_id: { $in: stageIds } });

  if (checklists.length === 0) {
    return res.status(200).json(
      new ApiResponse(
        200,
        {
          projectId,
          totalCheckpoints: 0,
          totalDefects: 0,
          defectRate: "0%",
          defectsByPhase: [],
          defectsByChecklist: [],
          categoryDistribution: [],
        },
        "No checklists found for this project"
      )
    );
  }

  // Get all checkpoints for these checklists
  const checklistIds = checklists.map((c) => c._id);
  const checkpoints = await Checkpoint.find({
    checklistId: { $in: checklistIds },
  });

  // Calculate defect statistics
  const totalCheckpoints = checkpoints.length;
  const defectCheckpoints = checkpoints.filter((cp) => cp.defect.isDetected);
  const totalDefects = defectCheckpoints.length;
  const defectRate =
    totalCheckpoints === 0
      ? "0%"
      : ((totalDefects / totalCheckpoints) * 100).toFixed(2) + "%";

  // Defects by phase
  const stageMap = new Map(stages.map((s) => [s._id.toString(), s]));
  const checklistMap = new Map(checklists.map((c) => [c._id.toString(), c]));

  const defectsByPhase = {};
  stages.forEach((stage) => {
    defectsByPhase[stage._id.toString()] = {
      stageId: stage._id,
      stageName: stage.stage_name,
      totalCheckpoints: 0,
      defectCount: 0,
      defectRate: "0%",
    };
  });

  // Defects by checklist
  const defectsByChecklist = {};
  checklists.forEach((checklist) => {
    defectsByChecklist[checklist._id.toString()] = {
      checklistId: checklist._id,
      checklistName: checklist.checklist_name,
      totalCheckpoints: 0,
      defectCount: 0,
      defectRate: "0%",
    };
  });

  // Category distribution
  const categoryDistribution = {};

  // Aggregate statistics
  checkpoints.forEach((checkpoint) => {
    const checklistId = checkpoint.checklistId.toString();
    const checklist = checklistMap.get(checklistId);

    if (checklist) {
      const stageId = checklist.stage_id.toString();

      // Update by phase
      if (defectsByPhase[stageId]) {
        defectsByPhase[stageId].totalCheckpoints += 1;
      }

      // Update by checklist
      if (defectsByChecklist[checklistId]) {
        defectsByChecklist[checklistId].totalCheckpoints += 1;
      }

      if (checkpoint.defect.isDetected) {
        // Update defect count by phase
        if (defectsByPhase[stageId]) {
          defectsByPhase[stageId].defectCount += 1;
        }

        // Update defect count by checklist
        if (defectsByChecklist[checklistId]) {
          defectsByChecklist[checklistId].defectCount += 1;
        }

        // Track category distribution
        const categoryId = checkpoint.defect.categoryId || "Unassigned";
        categoryDistribution[categoryId] =
          (categoryDistribution[categoryId] || 0) + 1;
      }
    }
  });

  // Calculate defect rates
  Object.values(defectsByPhase).forEach((phase) => {
    phase.defectRate =
      phase.totalCheckpoints === 0
        ? "0%"
        : ((phase.defectCount / phase.totalCheckpoints) * 100).toFixed(2) + "%";
  });

  Object.values(defectsByChecklist).forEach((checklist) => {
    checklist.defectRate =
      checklist.totalCheckpoints === 0
        ? "0%"
        : ((checklist.defectCount / checklist.totalCheckpoints) * 100).toFixed(
            2
          ) + "%";
  });

  // Convert to arrays and sort
  const phaseArray = Object.values(defectsByPhase).sort(
    (a, b) => b.defectCount - a.defectCount
  );
  const checklistArray = Object.values(defectsByChecklist).sort(
    (a, b) => b.defectCount - a.defectCount
  );
  const categoryArray = Object.entries(categoryDistribution)
    .map(([categoryId, count]) => ({
      categoryId,
      count,
      percentage: ((count / totalDefects) * 100).toFixed(2) + "%",
    }))
    .sort((a, b) => b.count - a.count);

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        projectId,
        summary: {
          totalCheckpoints,
          totalDefects,
          defectRate,
        },
        defectsByPhase: phaseArray,
        defectsByChecklist: checklistArray,
        categoryDistribution: categoryArray,
      },
      "Project analysis retrieved successfully"
    )
  );
});

/**
 * GET DEFECTS PER PHASE
 * GET /api/v1/projects/:projectId/analysis/defects-per-phase
 * Returns detailed defect breakdown by phase/stage
 */
export const getDefectsPerPhase = asyncHandler(async (req, res) => {
  const { projectId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  const stages = await Stage.find({ project_id: projectId });
  const stageIds = stages.map((s) => s._id);
  const checklists = await Checklist.find({ stage_id: { $in: stageIds } });
  const checklistIds = checklists.map((c) => c._id);
  const checkpoints = await Checkpoint.find({
    checklistId: { $in: checklistIds },
  });

  const result = stages.map((stage) => {
    const stageChecklists = checklists.filter(
      (c) => c.stage_id.toString() === stage._id.toString()
    );
    const checklistIdsForStage = stageChecklists.map((c) => c._id);
    const checkpointsInStage = checkpoints.filter((cp) =>
      checklistIdsForStage.includes(cp.checklistId)
    );

    const totalCheckpoints = checkpointsInStage.length;
    const defectCount = checkpointsInStage.filter(
      (cp) => cp.defect.isDetected
    ).length;

    return {
      stageId: stage._id,
      stageName: stage.stage_name,
      totalCheckpoints,
      defectCount,
      defectRate:
        totalCheckpoints === 0
          ? "0%"
          : ((defectCount / totalCheckpoints) * 100).toFixed(2) + "%",
    };
  });

  return res
    .status(200)
    .json(
      new ApiResponse(200, result, "Defects per phase retrieved successfully")
    );
});

/**
 * GET DEFECTS PER CHECKLIST
 * GET /api/v1/projects/:projectId/analysis/defects-per-checklist
 * Returns detailed defect breakdown by checklist
 */
export const getDefectsPerChecklist = asyncHandler(async (req, res) => {
  const { projectId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  const stages = await Stage.find({ project_id: projectId });
  const stageIds = stages.map((s) => s._id);
  const checklists = await Checklist.find({ stage_id: { $in: stageIds } });
  const checklistIds = checklists.map((c) => c._id);
  const checkpoints = await Checkpoint.find({
    checklistId: { $in: checklistIds },
  });

  const result = checklists.map((checklist) => {
    const checkpointsInChecklist = checkpoints.filter(
      (cp) => cp.checklistId.toString() === checklist._id.toString()
    );

    const totalCheckpoints = checkpointsInChecklist.length;
    const defectCount = checkpointsInChecklist.filter(
      (cp) => cp.defect.isDetected
    ).length;

    return {
      checklistId: checklist._id,
      checklistName: checklist.checklist_name,
      stageId: checklist.stage_id,
      totalCheckpoints,
      defectCount,
      defectRate:
        totalCheckpoints === 0
          ? "0%"
          : ((defectCount / totalCheckpoints) * 100).toFixed(2) + "%",
    };
  });

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        result,
        "Defects per checklist retrieved successfully"
      )
    );
});

/**
 * GET DEFECT CATEGORY DISTRIBUTION
 * GET /api/v1/projects/:projectId/analysis/category-distribution
 * Returns how defects are distributed across categories
 */
export const getCategoryDistribution = asyncHandler(async (req, res) => {
  const { projectId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  const stages = await Stage.find({ project_id: projectId });
  const stageIds = stages.map((s) => s._id);
  const checklists = await Checklist.find({ stage_id: { $in: stageIds } });
  const checklistIds = checklists.map((c) => c._id);
  const checkpoints = await Checkpoint.find({
    checklistId: { $in: checklistIds },
  });

  // Get only defected checkpoints
  const defectedCheckpoints = checkpoints.filter((cp) => cp.defect.isDetected);
  const totalDefects = defectedCheckpoints.length;

  if (totalDefects === 0) {
    return res
      .status(200)
      .json(
        new ApiResponse(
          200,
          { totalDefects: 0, distribution: [] },
          "No defects found"
        )
      );
  }

  // Group by category
  const categoryMap = {};
  defectedCheckpoints.forEach((checkpoint) => {
    const categoryId = checkpoint.defect.categoryId || "Unassigned";
    categoryMap[categoryId] = (categoryMap[categoryId] || 0) + 1;
  });

  // Convert to array and calculate percentages
  const distribution = Object.entries(categoryMap)
    .map(([categoryId, count]) => ({
      categoryId,
      count,
      percentage: ((count / totalDefects) * 100).toFixed(2) + "%",
    }))
    .sort((a, b) => b.count - a.count);

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { totalDefects, distribution },
        "Category distribution retrieved successfully"
      )
    );
});
