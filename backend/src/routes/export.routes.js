import express from 'express';
import authMiddleware from '../middleware/auth.Middleware.js';
import { exportMasterExcel } from '../controllers/export.controller.js';

const router = express.Router();

/**
 * Master Excel Export Routes
 * Protected by auth middleware - accessible to all authenticated users
 */

// GET /admin/export/master-excel - Download all project data as Excel
router.get(
  '/admin/export/master-excel',
  authMiddleware,
  exportMasterExcel
);

export default router;
