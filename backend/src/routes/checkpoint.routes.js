import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import {
  createCheckpoint,
  getCheckpointsByChecklistId,
  getCheckpointById,
  updateCheckpointResponse,
  deleteCheckpoint,
  assignDefectCategory,
  getDefectStatsByChecklist,
  suggestDefectCategory,
} from "../controllers/checkpoint.controller.js";

const router = express.Router();

/**
 * CHECKPOINT ROUTES
 * Base path: /api/v1
 */

// Get all checkpoints for a specific checklist
router.get("/checklists/:checklistId/checkpoints", getCheckpointsByChecklistId);

// Get defect statistics for a checklist (based on history)
router.get("/checklists/:checklistId/defect-stats", getDefectStatsByChecklist);

// Create a new checkpoint for a checklist (auth required)
router.post(
  "/checklists/:checklistId/checkpoints",
  authMiddleware,
  createCheckpoint
);

// Get a specific checkpoint by ID
router.get("/checkpoints/:checkpointId", getCheckpointById);

// Update checkpoint response (images are uploaded separately via GridFS /images route)
router.patch(
  "/checkpoints/:checkpointId",
  authMiddleware,
  updateCheckpointResponse
);

// Assign defect category to a checkpoint
router.patch(
  "/checkpoints/:checkpointId/defect-category",
  authMiddleware,
  assignDefectCategory
);

// Suggest defect category based on remark (no auth required for demo)
router.post(
  "/checkpoints/:checkpointId/suggest-category",
  suggestDefectCategory
);

// Delete a checkpoint (auth required)
router.delete("/checkpoints/:checkpointId", authMiddleware, deleteCheckpoint);

export default router;
