import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as analyticsService from "../services/analytics.service.js";
import {
  getRawAnalyticsData,
  computeAnalytics,
  getTeamLeadersList,
  getDefectCategoriesList,
  getProjectsList,
  getExecutorsList,
} from "../services/analytics-excel.service.js";

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Per-project analytics (unchanged â€“ keep existing functionality)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export const getProjectAnalysis = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const data = await analyticsService.getProjectAnalysis(projectId);
  const message = data.summary
    ? "Project analysis retrieved successfully"
    : data.defectsByPhase.length === 0
      ? "No stages found for this project"
      : "No checklists found for this project";
  return res.status(200).json(new ApiResponse(200, data, message));
});

export const getDefectsPerPhase = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const result = await analyticsService.getDefectsPerPhase(projectId);
  return res.status(200).json(new ApiResponse(200, result, "Defects per phase retrieved successfully"));
});

export const getDefectsPerChecklist = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const result = await analyticsService.getDefectsPerChecklist(projectId);
  return res.status(200).json(new ApiResponse(200, result, "Defects per checklist retrieved successfully"));
});

export const getCategoryDistribution = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  if (!mongoose.isValidObjectId(projectId)) throw new ApiError(400, "Invalid projectId");

  const data = await analyticsService.getCategoryDistribution(projectId);
  const message = data.totalDefects === 0 ? "No defects found" : "Category distribution retrieved successfully";
  return res.status(200).json(new ApiResponse(200, data, message));
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Dashboard Analytics  (Excel-data-driven)
//
// All endpoints read from the same ProjectChecklist + Project + Stage +
// Template data used by the master Excel export.  This guarantees the
// dashboard always matches the exported report.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/** Shared helper: load raw data and return filter params from query string. */
async function loadAndParse(req) {
  const { teamLeader, project, defectCategory, executor } = req.query;
  const { summaryRows, detailRows } = await getRawAnalyticsData();
  return { summaryRows, detailRows, teamLeader, project, defectCategory, executor };
}

// GET /analytics/summary
export const getDashboardSummary = asyncHandler(async (req, res) => {
  const { summaryRows, detailRows, teamLeader, project, defectCategory, executor } =
    await loadAndParse(req);

  const { summary } = computeAnalytics(summaryRows, detailRows, {
    teamLeader, project, defectCategory, executor,
  });

  return res.json(new ApiResponse(200, summary, "Summary fetched"));
});

// GET /analytics/top-defect-categories
export const getTopDefectCategories = asyncHandler(async (req, res) => {
  const { summaryRows, detailRows, teamLeader, project, defectCategory, executor } =
    await loadAndParse(req);

  const { topDefectCategories } = computeAnalytics(summaryRows, detailRows, {
    teamLeader, project, defectCategory, executor,
  });

  return res.json(
    new ApiResponse(200, topDefectCategories, "Top defect categories fetched"),
  );
});

// GET /analytics/defect-severity-distribution
export const getDefectSeverityDistribution = asyncHandler(async (req, res) => {
  const { summaryRows, detailRows, teamLeader, project, defectCategory, executor } =
    await loadAndParse(req);

  const { severityDistribution } = computeAnalytics(summaryRows, detailRows, {
    teamLeader, project, defectCategory, executor,
  });

  return res.json(
    new ApiResponse(200, severityDistribution, "Defect severity distribution fetched"),
  );
});

// GET /analytics/defect-details  (paginated + searchable)
export const getDefectDetails = asyncHandler(async (req, res) => {
  const {
    teamLeader,
    project,
    defectCategory,
    executor,
    page = "1",
    limit = "20",
    search = "",
  } = req.query;

  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

  const { summaryRows, detailRows } = await getRawAnalyticsData();
  const { defectDetails } = computeAnalytics(summaryRows, detailRows, {
    teamLeader, project, defectCategory, executor,
    page: pageNum, limitNum, search,
  });

  return res.json(
    new ApiResponse(200, defectDetails, "Defect details fetched"),
  );
});

// GET /analytics/team-leaders
export const getDashboardTeamLeaders = asyncHandler(async (req, res) => {
  const { summaryRows } = await getRawAnalyticsData();
  const names = getTeamLeadersList(summaryRows);
  return res.json(new ApiResponse(200, names, "Team leaders fetched"));
});

// GET /analytics/defect-categories
export const getDashboardDefectCategories = asyncHandler(async (req, res) => {
  const { detailRows } = await getRawAnalyticsData();
  const categories = getDefectCategoriesList(detailRows);
  return res.json(new ApiResponse(200, categories, "Defect categories fetched"));
});

// GET /analytics/executors
export const getDashboardExecutors = asyncHandler(async (req, res) => {
  const { allExecutors } = await getRawAnalyticsData();
  return res.json(new ApiResponse(200, allExecutors || [], "Executors fetched"));
});

// GET /analytics/dr-by-project
export const getDrByProject = asyncHandler(async (req, res) => {
  const { teamLeader, project, defectCategory, executor } = req.query;
  const { summaryRows, detailRows } = await getRawAnalyticsData();

  const { drByProject } = computeAnalytics(summaryRows, detailRows, {
    teamLeader, project, defectCategory, executor,
  });

  return res.json(new ApiResponse(200, drByProject, "DR by project fetched"));
});

// GET /analytics/dr-by-team-leader
export const getDrByTeamLeader = asyncHandler(async (req, res) => {
  const { teamLeader, project, defectCategory, executor } = req.query;
  const { summaryRows, detailRows } = await getRawAnalyticsData();

  const { drByTeamLeader } = computeAnalytics(summaryRows, detailRows, {
    teamLeader, project, defectCategory, executor,
  });

  return res.json(new ApiResponse(200, drByTeamLeader, "DR by team leader fetched"));
});

// GET /analytics/projects  (lightweight list for filter dropdown)
export const getDashboardProjects = asyncHandler(async (req, res) => {
  const { summaryRows } = await getRawAnalyticsData();
  const data = getProjectsList(summaryRows);
  return res.json(new ApiResponse(200, data, "Projects fetched"));
});

