import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import {
  getProjectAnalysis,
  getDefectsPerPhase,
  getDefectsPerChecklist,
  getCategoryDistribution,
  getDashboardSummary,
  getTopDefectCategories,
  getAllDefectCategories,
  getDefectSeverityDistribution,
  getDefectDetails,
  getDashboardTeamLeaders,
  getDashboardDefectCategories,
  getDashboardExecutors,
  getDrByProject,
  getDrByTeamLeader,
  getDashboardProjects,
} from "../controllers/analytics.controller.js";

const router = express.Router();

/**
 * ANALYTICS ROUTES
 * Base path: /api/v1
 * All routes require authentication
 */

// ── Per-project analytics (existing) ────────────────────────────────────────
router.get("/projects/:projectId/analysis", authMiddleware, getProjectAnalysis);
router.get(
  "/projects/:projectId/analysis/defects-per-phase",
  authMiddleware,
  getDefectsPerPhase,
);
router.get(
  "/projects/:projectId/analysis/defects-per-checklist",
  authMiddleware,
  getDefectsPerChecklist,
);
router.get(
  "/projects/:projectId/analysis/category-distribution",
  authMiddleware,
  getCategoryDistribution,
);

// ── Dashboard analytics (new) ────────────────────────────────────────────────
router.get("/analytics/summary", getDashboardSummary);
router.get("/analytics/top-defect-categories", getTopDefectCategories);
router.get("/analytics/all-defect-categories", getAllDefectCategories);
router.get(
  "/analytics/defect-severity-distribution",
  getDefectSeverityDistribution,
);
router.get("/analytics/defect-details", getDefectDetails);
router.get("/analytics/team-leaders", getDashboardTeamLeaders);
router.get("/analytics/defect-categories", getDashboardDefectCategories);
router.get("/analytics/executors", getDashboardExecutors);
router.get("/analytics/dr-by-project", getDrByProject);
router.get("/analytics/dr-by-team-leader", getDrByTeamLeader);
router.get("/analytics/projects", getDashboardProjects);

export default router;
