import express from "express";
import {
  getChecklistAnswers,
  saveChecklistAnswers,
  submitChecklistAnswers,
  getSubmissionStatus,
} from "../controllers/checklistAnswer.controller.js";

const router = express.Router();

router.get("/projects/:projectId/checklist-answers", getChecklistAnswers);
router.put("/projects/:projectId/checklist-answers", saveChecklistAnswers);
router.post(
  "/projects/:projectId/checklist-answers/submit",
  submitChecklistAnswers,
);
router.get(
  "/projects/:projectId/checklist-answers/submission-status",
  getSubmissionStatus,
);

export default router;
