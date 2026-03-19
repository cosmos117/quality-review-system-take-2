import * as projectService from "../services/project.service.js";

// Get all projects
export const getAllProjects = async (req, res) => {
  try {
    const result = await projectService.getAllProjects(req.query);
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get projects for a specific user
export const getProjectsForUser = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res
        .status(400)
        .json({ success: false, message: "User ID is required" });
    }
    const data = await projectService.getProjectsForUser(userId);
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get project by ID
export const getProjectById = async (req, res) => {
  try {
    const project = await projectService.getProjectById(req.params.id);
    res.status(200).json({ success: true, data: project });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};

// Create new project
export const createProject = async (req, res) => {
  try {
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
      isReviewApplicable,
      reviewApplicableRemark,
      templateName,
    } = req.body;

    const creatorId = req.user?._id || created_by;

    const project = await projectService.createProject({
      project_no,
      internal_order_no,
      project_name,
      description,
      status,
      priority,
      start_date,
      end_date,
      created_by: creatorId,
      isReviewApplicable,
      reviewApplicableRemark,
      templateName,
    });

    res.status(201).json({ success: true, data: project });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Update project
export const updateProject = async (req, res) => {
  try {
    const project = await projectService.updateProject(
      req.params.id,
      req.body,
      req.user?._id,
    );
    res.status(200).json({ success: true, data: project });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};

// Sync existing checkpoints with template categories
export const syncCheckpointCategories = async (req, res) => {
  try {
    await projectService.syncProjectCheckpointCategories(req.params.projectId);
    res.status(200).json({
      success: true,
      message: "Checkpoints synced with template categories",
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get all stages for a project
export const getProjectStages = async (req, res) => {
  try {
    const stageData = await projectService.getProjectStages(
      req.params.projectId,
    );
    const message =
      stageData.length === 0
        ? "No stages found for this project"
        : "Project stages fetched successfully";
    res.status(200).json({ success: true, data: stageData, message });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Delete project
export const deleteProject = async (req, res) => {
  try {
    const deletionStats = await projectService.deleteProject(req.params.id);
    res.status(200).json({
      success: true,
      message: "Project and all related data deleted successfully",
      deletionStats,
    });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};
