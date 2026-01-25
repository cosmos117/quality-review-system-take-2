import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import { requireAdmin } from "../middleware/role.middleware.js";
// Routes updated: 2025-01-25 - Fixed PATCH/PUT methods
import {
  createTemplate,
  getTemplate,
  addChecklistToTemplate,
  updateChecklistInTemplate,
  deleteChecklistFromTemplate,
  addCheckpointToTemplate,
  updateCheckpointInTemplate,
  deleteCheckpointFromTemplate,
  seedTemplate,
  updateDefectCategories,
  addSectionToChecklist,
  updateSectionInChecklist,
  deleteSectionFromChecklist,
  addCheckpointToSection,
  updateCheckpointInSection,
  deleteCheckpointFromSection,
  addStageToTemplate,
  deleteStageFromTemplate,
  getAllStages,
  resetTemplate,
} from "../controllers/template.controller.js";

const router = express.Router();

/**
 * TEMPLATE ROUTES
 * Base path: /api/v1/templates
 *
 * Note: Only ONE template exists in the system
 */

// Seed template with sample data (for testing/setup)
router.post("/seed", authMiddleware, requireAdmin, seedTemplate);
router.post("/", authMiddleware, requireAdmin, createTemplate);
router.get("/", getTemplate);

// ========== CHECKLIST OPERATIONS ==========
router.post(
  "/checklists",
  authMiddleware,
  requireAdmin,
  addChecklistToTemplate,
);
router.patch(
  "/checklists/:checklistId",
  authMiddleware,
  requireAdmin,
  updateChecklistInTemplate,
);
router.delete(
  "/checklists/:checklistId",
  authMiddleware,
  requireAdmin,
  deleteChecklistFromTemplate,
);

// ========== CHECKPOINT OPERATIONS ==========
router.post(
  "/checklists/:checklistId/checkpoints",
  authMiddleware,
  requireAdmin,
  addCheckpointToTemplate,
);
router.post(
  "/checklists/:checklistId/sections/:sectionId/checkpoints",
  authMiddleware,
  requireAdmin,
  addCheckpointToSection,
);
router.patch(
  "/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  updateCheckpointInSection,
);
router.delete(
  "/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromSection,
);
router.patch(
  "/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  updateCheckpointInTemplate,
);
router.delete(
  "/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromTemplate,
);

// ========== SECTION OPERATIONS ==========
router.post(
  "/checklists/:checklistId/sections",
  authMiddleware,
  requireAdmin,
  addSectionToChecklist,
);
router.put(
  "/checklists/:checklistId/sections/:sectionId",
  authMiddleware,
  requireAdmin,
  updateSectionInChecklist,
);
router.delete(
  "/checklists/:checklistId/sections/:sectionId",
  authMiddleware,
  requireAdmin,
  deleteSectionFromChecklist,
);

// ========== DEFECT CATEGORY OPERATIONS ==========
router.patch(
  "/defect-categories",
  authMiddleware,
  requireAdmin,
  updateDefectCategories,
);
// ========== STAGE OPERATIONS ==========
router.get("/stages", getTemplate);
router.post("/stages", authMiddleware, requireAdmin, addStageToTemplate);
router.delete("/stages/:stage", authMiddleware, requireAdmin, deleteStageFromTemplate);
router.delete("/reset", authMiddleware, requireAdmin, resetTemplate);

export default router;
