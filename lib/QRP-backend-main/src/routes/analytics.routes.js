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
router.get(
  '/projects/:projectId/analysis',
  authMiddleware,
  getProjectAnalysis
);
router.get(
  '/projects/:projectId/analysis/defects-per-phase',
  authMiddleware,
  getDefectsPerPhase
);
router.get(
  '/projects/:projectId/analysis/defects-per-checklist',
  authMiddleware,
  getDefectsPerChecklist
);
router.get(
  '/projects/:projectId/analysis/category-distribution',
  authMiddleware,
  getCategoryDistribution
);

export default router;
