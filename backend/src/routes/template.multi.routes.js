import { Router } from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import * as templateController from "../controllers/template.multi.controller.js";

const router = Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

// Template Management 

// Get all templates list (for dropdown)
router.get("/list", templateController.getAllTemplateNames);

// Create new template
router.post("/", templateController.createTemplate);

// Save full template payload with a new template name
router.post("/save", templateController.saveTemplatePayload);

// Save full template payload into an existing template
router.put("/:templateName/save", templateController.updateTemplatePayload);

// Get specific template (with optional stage filter)
router.get("/:templateName", templateController.getTemplate);

// Update template metadata
router.patch("/:templateName", templateController.updateTemplate);

// Delete template
router.delete("/:templateName", templateController.deleteTemplate);

// Duplicate template
router.post("/:templateName/duplicate", templateController.duplicateTemplate);

// Stage Management 

// Get all stages in a template
router.get("/:templateName/stages", templateController.getAllStages);

// Add new stage
router.post("/:templateName/stages", templateController.addStageToTemplate);

// Delete stage
router.delete(
  "/:templateName/stages/:stage",
  templateController.deleteStageFromTemplate,
);

// Checklist (Group) Management 

// Add checklist group
router.post(
  "/:templateName/checklists",
  templateController.addChecklistToTemplate,
);

// Update checklist group
router.patch(
  "/:templateName/checklists/:checklistId",
  templateController.updateChecklistInTemplate,
);

// Delete checklist group
router.delete(
  "/:templateName/checklists/:checklistId",
  templateController.deleteChecklistFromTemplate,
);

// Checkpoint Management on Checklists 

// Add checkpoint to checklist
router.post(
  "/:templateName/checklists/:checklistId/checkpoints",
  templateController.addCheckpointToTemplate,
);

// Update checkpoint in checklist
router.patch(
  "/:templateName/checklists/:checklistId/checkpoints/:checkpointId",
  templateController.updateCheckpointInTemplate,
);

// Delete checkpoint from checklist
router.delete(
  "/:templateName/checklists/:checklistId/checkpoints/:checkpointId",
  templateController.deleteCheckpointFromTemplate,
);

// Section Management 

// Add section to checklist
router.post(
  "/:templateName/checklists/:checklistId/sections",
  templateController.addSectionToChecklist,
);

// Update section in checklist
router.patch(
  "/:templateName/checklists/:checklistId/sections/:sectionId",
  templateController.updateSectionInChecklist,
);

// Delete section from checklist
router.delete(
  "/:templateName/checklists/:checklistId/sections/:sectionId",
  templateController.deleteSectionFromChecklist,
);

// Checkpoint Management on Sections 

// Add checkpoint to section
router.post(
  "/:templateName/checklists/:checklistId/sections/:sectionId/checkpoints",
  templateController.addCheckpointToSection,
);

// Update checkpoint in section
router.patch(
  "/:templateName/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  templateController.updateCheckpointInSection,
);

// Delete checkpoint from section
router.delete(
  "/:templateName/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  templateController.deleteCheckpointFromSection,
);

// Defect Categories 

// Update defect categories
router.put(
  "/:templateName/categories",
  templateController.updateDefectCategories,
);

// Seed 

// Seed sample templates
router.post("/seed/sample", templateController.seedSampleTemplates);

export default router;
