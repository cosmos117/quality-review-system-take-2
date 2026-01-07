import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import {
  getProjectChecklist,
  updateExecutorAnswer,
  updateReviewerStatus,
} from "../controllers/projectChecklist.controller.js";

const router = express.Router();

router.get(
  "/projects/:projectId/stages/:stageId/project-checklist",
  authMiddleware,
  getProjectChecklist
);

router.patch(
  "/projects/:projectId/stages/:stageId/checklist/groups/:groupId/questions/:questionId/executor",
  authMiddleware,
  updateExecutorAnswer
);

router.patch(
  "/projects/:projectId/stages/:stageId/checklist/groups/:groupId/questions/:questionId/reviewer",
  authMiddleware,
  updateReviewerStatus
);

export default router;
