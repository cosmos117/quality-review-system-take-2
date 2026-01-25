import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Project from "../models/project.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";
import Checklist from "../models/checklist.models.js";
import Checkpoint from "../models/checkpoint.models.js";

// Helper function to sync existing checkpoints with template categories
// Optimized: Uses lean() for read-only queries and batch operations
async function syncCheckpointsWithTemplate(projectId) {
  try {
    const template = await Template.findOne().lean();
    if (!template) return;

    const stages = await Stage.find({ project_id: projectId }).lean();
    const stageMappings = {
      "Phase 1": "stage1",
      "Phase 2": "stage2",
      "Phase 3": "stage3",
    };

    for (const stage of stages) {
      const templateStageKey = stageMappings[stage.stage_name];
      if (!templateStageKey) continue;

      const templateChecklists = template[templateStageKey] || [];
      const checklists = await Checklist.find({ stage_id: stage._id }).lean();

      for (const checklist of checklists) {
        const templateChecklist = templateChecklists.find(
          (tc) => tc.text === checklist.checklist_name
        );
        if (!templateChecklist) continue;

        const updates = [];
        for (const checkpoint of checklist.checkpoints || []) {
          const templateCheckpoint = templateChecklist.checkpoints?.find(
            (tcp) => tcp.text === checkpoint.question
          );
          if (templateCheckpoint?.categoryId) {
            updates.push({
              updateOne: {
                filter: { _id: checkpoint._id },
                update: { categoryId: templateCheckpoint.categoryId },
              },
            });
          }
        }
        if (updates.length > 0) {
          await Checkpoint.bulkWrite(updates);
        }
      }
    }
  } catch (error) {
    // Silently handle sync errors - not critical
  }
}

/**
 * CREATE - POST /api/projects
 * Creates a new project
 * Body: { project_no, internal_order_no, project_name, description, status, priority, start_date, end_date, created_by }
 */
export const createProject = asyncHandler(async (req, res) => {
  const {
    project_no,
    internal_order_no,
    project_name,
    description,
    status,
    priority,
    start_date,
    end_date,
    created_by,
  } = req.body;

  // Prefer authenticated user as creator
  const creatorId = req.user?._id || created_by;

  const project = await Project.create({
    project_no,
    internal_order_no,
    project_name,
    description,
    status,
    priority,
    start_date,
    end_date,
    created_by: creatorId,
  });

  // Populate the created project
  const populatedProject = await Project.findById(project._id).populate(
    "created_by",
    "name email"
  );

  return res
    .status(201)
    .json(
      new ApiResponse(201, populatedProject, "Project created successfully")
    );
});

/**
 * READ - GET /api/projects/:id
 * Retrieves a single project by ID
 */
export const getProjectById = asyncHandler(async (req, res) => {
  const project = await Project.findById(req.params.id).populate(
    "created_by",
    "name email"
  );

  if (!project) {
    throw new ApiError(404, "Project not found");
  }

  return res
    .status(200)
    .json(new ApiResponse(200, project, "Project retrieved successfully"));
});

/**
 * READ - GET /api/projects
 * Retrieves all projects with optional pagination
 */
export const getAllProjects = asyncHandler(async (req, res) => {
  const { page = 1, limit = 10, status, priority } = req.query;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const filter = {};
  if (status) filter.status = status;
  if (priority) filter.priority = priority;

  const projects = await Project.find(filter)
    .populate("created_by", "name email")
    .skip(skip)
    .limit(parseInt(limit))
    .sort({ created_at: -1 });

  const total = await Project.countDocuments(filter);

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        projects,
        pagination: { page: parseInt(page), limit: parseInt(limit), total },
      },
      "Projects retrieved successfully"
    )
  );
});

/**
 * UPDATE - PUT /api/projects/:id
 * Updates a project
 * Body: { project_no, internal_order_no, project_name, description, status, priority, start_date, end_date }
 */
export const updateProject = asyncHandler(async (req, res) => {
  const {
    project_no,
    internal_order_no,
    project_name,
    description,
    status,
    priority,
    start_date,
    end_date,
  } = req.body;

  const existing = await Project.findById(req.params.id);
  if (!existing) {
    throw new ApiError(404, "Project not found");
  }

  const prevStatus = existing.status;

  // Guard: only assigned users may start the project
  const requestedStatus =
    typeof status === "string" ? status : existing.status;
  if (prevStatus === "pending" && requestedStatus === "in_progress") {
    const assigned = await ProjectMembership.findOne({
      project_id: existing._id,
      user_id: req.user?._id,
    });
    if (!assigned) {
      throw new ApiError(
        403,
        "Only assigned users can start this project"
      );
    }
  }

  // Perform update
  existing.project_no = project_no ?? existing.project_no;
  existing.internal_order_no =
    internal_order_no ?? existing.internal_order_no;
  if (typeof project_name === "string") existing.project_name = project_name;
  if (typeof description === "string") existing.description = description;
  if (typeof status === "string") existing.status = status;
  if (typeof priority === "string") existing.priority = priority;
  if (start_date) existing.start_date = start_date;
  if (end_date) existing.end_date = end_date;
  await existing.save();

  const project = await Project.findById(existing._id).populate(
    "created_by",
    "name email"
  );

  // If status changed from pending -> in_progress, assign template to this project
  if (prevStatus === "pending" && existing.status === "in_progress") {
    const existingStagesCount = await Stage.countDocuments({
      project_id: existing._id,
    });
    if (existingStagesCount === 0) {
      const template = await Template.findOne();
      if (template) {
        const creatorId = req.user?._id || project.created_by?._id;
        const stageDefs = [
          { name: "Phase 1", key: "stage1" },
          { name: "Phase 2", key: "stage2" },
          { name: "Phase 3", key: "stage3" },
        ];

        const stageDocs = [];
        for (const def of stageDefs) {
          const stage = await Stage.create({
            project_id: existing._id,
            stage_name: def.name,
            status: "pending",
            created_by: creatorId,
          });
          stageDocs.push({ doc: stage, key: def.key });
        }

        for (const { doc: stage, key } of stageDocs) {
          const checklists = template[key] || [];
          for (const cl of checklists) {
            const checklist = await Checklist.create({
              stage_id: stage._id,
              created_by: creatorId,
              checklist_name: cl.text,
              description: "",
              status: "draft",
              revision_number: 0,
              answers: {},
            });
            const cps = cl.checkpoints || [];
            for (const cp of cps) {
              await Checkpoint.create({
                checklistId: checklist._id,
                question: cp.text,
                categoryId: cp.categoryId || undefined,
                executorResponse: {},
                reviewerResponse: {},
              });
            }
          }
        }
      }
    }
  }

  return res
    .status(200)
    .json(new ApiResponse(200, project, "Project updated successfully"));
});

/**
 * SYNC - POST /api/projects/:projectId/sync-checkpoints
 * Syncs existing checkpoints with template categories
 */
export const syncCheckpointCategories = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  await syncCheckpointsWithTemplate(projectId);

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        {},
        "Checkpoints synced with template categories"
      )
    );
});

/**
 * DELETE - DELETE /api/projects/:id
 * Deletes a project (cascades to related documents)
 */
export const deleteProject = asyncHandler(async (req, res) => {
  const project = await Project.findById(req.params.id);

  if (!project) {
    throw new ApiError(404, "Project not found");
  }

  // Cascade delete: Remove all project memberships associated with this project
  const deletedMemberships = await ProjectMembership.deleteMany({
    project_id: req.params.id,
  });

  await Project.findByIdAndDelete(req.params.id);

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { deletedMemberships: deletedMemberships.deletedCount },
        "Project deleted successfully"
      )
    );
});
