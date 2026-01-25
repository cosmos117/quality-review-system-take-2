import Project from "../models/project.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";
import Checklist from "../models/checklist.models.js";
import Checkpoint from "../models/checkpoint.models.js";
import ProjectChecklist from "../models/projectChecklist.models.js";

// Helper function to sync existing checkpoints with template categories
async function syncCheckpointsWithTemplate(projectId) {
  try {
    const template = await Template.findOne();
    if (!template) return;

    const stages = await Stage.find({ project_id: projectId });
    const stageMappings = {
      "Phase 1": "stage1",
      "Phase 2": "stage2",
      "Phase 3": "stage3",
    };

    for (const stage of stages) {
      const templateStageKey = stageMappings[stage.stage_name];
      if (!templateStageKey) continue;

      const templateChecklists = template[templateStageKey] || [];
      const checklists = await Checklist.find({ stage_id: stage._id });

      for (const checklist of checklists) {
        const templateChecklist = templateChecklists.find(
          (tc) => tc.text === checklist.checklist_name,
        );
        if (!templateChecklist) continue;

        for (const checkpoint of checklist.checkpoints || []) {
          const templateCheckpoint = templateChecklist.checkpoints?.find(
            (tcp) => tcp.text === checkpoint.question,
          );
          if (templateCheckpoint?.categoryId) {
            await Checkpoint.updateOne(
              { _id: checkpoint._id },
              { categoryId: templateCheckpoint.categoryId },
            );
          }
        }
      }
    }
    console.log("✓ Checkpoints synced with template categories");
  } catch (error) {
    console.error(
      "⚠️ Failed to sync checkpoints with template:",
      error.message,
    );
  }
}

// Get all projects
export const getAllProjects = async (req, res) => {
  try {
    const projects = await Project.find({})
      .populate("created_by", "name email")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      data: projects,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get project by ID
export const getProjectById = async (req, res) => {
  try {
    const project = await Project.findById(req.params.id).populate(
      "created_by",
      "name email",
    );

    if (!project) {
      return res.status(404).json({
        success: false,
        message: "Project not found",
      });
    }

    res.status(200).json({
      success: true,
      data: project,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
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

    // Auto-create stages and checklists from template
    await createStagesAndChecklistsFromTemplate(project._id);

    // Populate the created project
    const populatedProject = await Project.findById(project._id).populate(
      "created_by",
      "name email",
    );

    res.status(201).json({
      success: true,
      data: populatedProject,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Helper: Create stages and project checklists from template
 * Called automatically when a project is created
 */
async function createStagesAndChecklistsFromTemplate(projectId) {
  try {
    const template = await Template.findOne();
    if (!template) {
      console.log("⚠️ No template found, skipping stage/checklist creation");
      return;
    }

    // Get all stage keys from template (stage1, stage2, stage3, etc.)
    const stageKeys = Object.keys(template.toObject())
      .filter((key) => /^stage\d{1,2}$/.test(key))
      .sort((a, b) => {
        const numA = parseInt(a.replace("stage", ""));
        const numB = parseInt(b.replace("stage", ""));
        return numA - numB;
      });

    const stageNames = template.stageNames || {};

    console.log(
      `📋 Creating stages and checklists from template for project ${projectId}`,
    );
    console.log(`   Found stages: ${stageKeys.join(", ")}`);

    // Create a stage for each template stage
    for (const stageKey of stageKeys) {
      const stageNum = parseInt(stageKey.replace("stage", ""));
      const stageName = stageNames[stageKey] || `Phase ${stageNum}`;

      // Create stage
      const stage = await Stage.create({
        project_id: projectId,
        stage_name: stageName,
        stage_key: stageKey,
        status: "pending",
      });

      console.log(`✅ Created stage: ${stageName} (${stageKey})`);

      // Get checklist groups from template stage
      const templateGroups = template[stageKey] || [];

      // Create project checklist
      const groups = templateGroups.map((templateGroup) => ({
        groupName: templateGroup.text,
        questions: (templateGroup.checkpoints || []).map((cp) => ({
          text: cp.text,
          executorAnswer: null,
          executorRemark: "",
          reviewerStatus: null,
          reviewerRemark: "",
        })),
        sections: (templateGroup.sections || []).map((section) => ({
          sectionName: section.text,
          questions: (section.checkpoints || []).map((cp) => ({
            text: cp.text,
            executorAnswer: null,
            executorRemark: "",
            reviewerStatus: null,
            reviewerRemark: "",
          })),
        })),
      }));

      const projectChecklist = await ProjectChecklist.create({
        projectId,
        stageId: stage._id,
        stage: stageKey,
        groups,
      });

      console.log(
        `✅ Created checklist for ${stageName} with ${groups.length} groups`,
      );
    }

    console.log(
      `✅ All stages and checklists created successfully for project ${projectId}`,
    );
  } catch (error) {
    console.error(
      "❌ Failed to create stages and checklists from template:",
      error.message,
    );
    // Don't throw - let project creation succeed even if template sync fails
  }
}

// Update project
export const updateProject = async (req, res) => {
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
    } = req.body;

    const existing = await Project.findById(req.params.id);
    if (!existing) {
      return res
        .status(404)
        .json({ success: false, message: "Project not found" });
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
        return res.status(403).json({
          success: false,
          message: "Only assigned users can start this project",
        });
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
      "name email",
    );

    // If status changed from pending -> in_progress, assign template to this project
    if (prevStatus === "pending" && existing.status === "in_progress") {
      console.log(
        "\n🚀 PROJECT STARTED - Cloning template to stages/checklists/checkpoints",
      );

      const existingStagesCount = await Stage.countDocuments({
        project_id: existing._id,
      });
      if (existingStagesCount === 0) {
        const template = await Template.findOne();
        console.log("Template found:", !!template);

        if (template) {
          console.log("Template structure:", {
            stage1: template.stage1?.length || 0,
            stage2: template.stage2?.length || 0,
            stage3: template.stage3?.length || 0,
          });

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
            console.log(`✓ Stage created: ${def.name} (${stage._id})`);
            stageDocs.push({ doc: stage, key: def.key });
          }

          for (const { doc: stage, key } of stageDocs) {
            const checklists = template[key] || [];
            console.log(
              `Processing ${stage.stage_name}: ${checklists.length} checklists`,
            );

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
              console.log(`  ✓ Checklist: ${cl.text}`);

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
              console.log(`    ✓ ${cps.length} checkpoints added`);
            }
          }

          console.log("✓ Template cloning completed\n");
        } else {
          console.log("❌ No template found in database");
        }
      }
    }

    res.status(200).json({ success: true, data: project });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Sync existing checkpoints with template categories
export const syncCheckpointCategories = async (req, res) => {
  try {
    const { projectId } = req.params;
    await syncCheckpointsWithTemplate(projectId);
    res.status(200).json({
      success: true,
      message: "Checkpoints synced with template categories",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get all stages for a project with their names
export const getProjectStages = async (req, res) => {
  try {
    const { projectId } = req.params;

    const stages = await Stage.find({ project_id: projectId }).sort({
      createdAt: 1,
    });

    if (!stages || stages.length === 0) {
      return res.status(200).json({
        success: true,
        data: [],
        message: "No stages found for this project",
      });
    }

    const stageData = stages.map((stage) => ({
      _id: stage._id,
      stage_name: stage.stage_name,
      stage_key: stage.stage_key,
      status: stage.status,
    }));

    res.status(200).json({
      success: true,
      data: stageData,
      message: "Project stages fetched successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Delete project
export const deleteProject = async (req, res) => {
  try {
    const project = await Project.findByIdAndDelete(req.params.id);

    if (!project) {
      return res.status(404).json({
        success: false,
        message: "Project not found",
      });
    }

    // Cascade delete: Remove all project memberships associated with this project
    const deletedMemberships = await ProjectMembership.deleteMany({
      project_id: req.params.id,
    });
    console.log(
      `[Project Delete] Removed ${deletedMemberships.deletedCount} membership(s) for project ${req.params.id}`,
    );

    res.status(200).json({
      success: true,
      message: "Project deleted successfully",
      deletedMemberships: deletedMemberships.deletedCount,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
