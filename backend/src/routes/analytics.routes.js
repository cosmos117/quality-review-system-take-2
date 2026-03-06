import express from 'express';
import authMiddleware from '../middleware/auth.Middleware.js';
import {
  getProjectAnalysis,
  getDefectsPerPhase,
  getDefectsPerChecklist,
  getCategoryDistribution,
} from '../controllers/analytics.controller.js';

const router = express.Router();

/**
 * ANALYTICS ROUTES
 * Base path: /api/v1
 * All routes require authentication
 */

// Get overall project analysis
router.get(
  '/projects/:projectId/analysis',
  authMiddleware,
  getProjectAnalysis
);

// Get defects per phase
router.get(
  '/projects/:projectId/analysis/defects-per-phase',
  authMiddleware,
  getDefectsPerPhase
);

// Get defects per checklist
router.get(
  '/projects/:projectId/analysis/defects-per-checklist',
  authMiddleware,
  getDefectsPerChecklist
);

// Get category distribution
router.get(
  '/projects/:projectId/analysis/category-distribution',
  authMiddleware,
  getCategoryDistribution
);

export default router;
