import express from 'express';
import authMiddleware from '../middleware/auth.Middleware.js';
import { requireAdmin } from '../middleware/role.middleware.js';
import { exportMasterExcel } from '../controllers/export.controller.js';

const router = express.Router();

/**
 * Master Excel Export Routes
 * Protected by admin auth middleware
 */

// GET /admin/export/master-excel - Download all project data as Excel
router.get(
  '/admin/export/master-excel',
  authMiddleware,
  requireAdmin,
  exportMasterExcel
);

export default router;
