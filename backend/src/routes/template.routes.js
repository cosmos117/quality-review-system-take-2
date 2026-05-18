import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import { requireAdmin } from "../middleware/role.middleware.js";
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
  renameStageInTemplate,
  deleteStageFromTemplate,
  getAllStages,
  resetTemplate,
} from "../controllers/template.controller.js";

const router = express.Router();

// Template routes — base path: /api/v1/templates

// Seed template with sample data (for testing/setup)
router.post("/seed", authMiddleware, requireAdmin, seedTemplate);

// Create template (only once, requires auth)
router.post("/", authMiddleware, requireAdmin, createTemplate);

// Get template
router.get("/", getTemplate);

// Checklist routes

// Add a checklist to a stage in the template
router.post(
  "/checklists",
  authMiddleware,
  requireAdmin,
  addChecklistToTemplate,
);

// Update a checklist in the template
router.patch(
  "/checklists/:checklistId",
  authMiddleware,
  requireAdmin,
  updateChecklistInTemplate,
);

// Delete a checklist from the template
router.delete(
  "/checklists/:checklistId",
  authMiddleware,
  requireAdmin,
  deleteChecklistFromTemplate,
);

// Checkpoint routes

// Add a checkpoint to a checklist in the template (direct to group)
router.post(
  "/checklists/:checklistId/checkpoints",
  authMiddleware,
  requireAdmin,
  addCheckpointToTemplate,
);

// Add a checkpoint to a section in a checklist in the template
router.post(
  "/checklists/:checklistId/sections/:sectionId/checkpoints",
  authMiddleware,
  requireAdmin,
  addCheckpointToSection,
);

// Update a checkpoint inside a section in the template
router.patch(
  "/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  updateCheckpointInSection,
);

// Delete a checkpoint from a section in a checklist in the template
router.delete(
  "/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromSection,
);

// Update a checkpoint in the template
router.patch(
  "/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  updateCheckpointInTemplate,
);

// Delete a checkpoint from the template
router.delete(
  "/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromTemplate,
);

// Section routes

// Add a section to a checklist group in the template
router.post(
  "/checklists/:checklistId/sections",
  authMiddleware,
  requireAdmin,
  addSectionToChecklist,
);

// Update a section in a checklist group in the template
router.put(
  "/checklists/:checklistId/sections/:sectionId",
  authMiddleware,
  requireAdmin,
  updateSectionInChecklist,
);

// Delete a section from a checklist group in the template
router.delete(
  "/checklists/:checklistId/sections/:sectionId",
  authMiddleware,
  requireAdmin,
  deleteSectionFromChecklist,
);

// Defect category routes

// Update defect categories in the template
router.patch(
  "/defect-categories",
  authMiddleware,
  requireAdmin,
  updateDefectCategories,
);
// Stage routes

// Get all available stages
router.get("/stages", getAllStages);

// Add a new stage to the template
router.post("/stages", authMiddleware, requireAdmin, addStageToTemplate);

// Rename an existing stage in the template
router.patch(
  "/stages/:stage/name",
  authMiddleware,
  requireAdmin,
  renameStageInTemplate,
);

// Delete a stage from the template
router.delete(
  "/stages/:stage",
  authMiddleware,
  requireAdmin,
  deleteStageFromTemplate,
);

// Reset template (delete all template data)
router.delete("/reset", authMiddleware, requireAdmin, resetTemplate);

export default router;
