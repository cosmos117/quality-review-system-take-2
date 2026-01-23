import ExcelJS from 'exceljs';
import { User } from '../models/user.models.js';
import Project from '../models/project.models.js';
import Stage from '../models/stage.models.js';
import { Role } from '../models/roles.models.js';
import ProjectMembership from '../models/projectMembership.models.js';
import Checkpoint from '../models/checkpoint.models.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';

/**
 * MASTER EXCEL EXPORT CONTROLLER
 * Generates a comprehensive multi-sheet Excel file for PowerBI analysis
 * Contains all project data, stages, roles, members, checkpoints, and derived defects
 */

// Helper: Safe value extraction (avoid undefined, use null/"")
const safeValue = (val, defaultVal = '') => {
  if (val === null || val === undefined) return defaultVal;
  if (typeof val === 'boolean') return val;
  return val;
};

// Helper: Add sheet with headers
const addSheetWithHeaders = (workbook, sheetName, columns) => {
  const sheet = workbook.addWorksheet(sheetName);
  const headerRow = sheet.addRow(columns);
  
  // Style headers
  headerRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF366092' } };
    cell.alignment = { horizontal: 'center', vertical: 'center', wrapText: true };
  });
  
  // Auto-fit columns
  sheet.columns.forEach((col) => {
    let maxLength = 15;
    col.eachCell({ includeEmpty: true }, (cell) => {
      if (cell.value) {
        const cellLength = cell.value.toString().length;
        if (cellLength > maxLength) maxLength = cellLength;
      }
    });
    col.width = Math.min(maxLength + 2, 50);
  });
  
  return sheet;
};

/**
 * GET /admin/export/master-excel
 * Main export endpoint - generates master Excel file with all data
 */
export const exportMasterExcel = asyncHandler(async (req, res) => {
  try {
    console.log('📊 Starting Master Excel export...');

    // Fetch all data in parallel
    const [users, projects, stages, roles, memberships, checkpoints] = await Promise.all([
      User.find().lean(),
      Project.find().populate('created_by', 'name email').lean(),
      Stage.find().lean(),
      Role.find().lean(),
      ProjectMembership.find().populate(['user_id', 'role']).lean(),
      Checkpoint.find().populate(['checklistId']).lean(),
    ]);

    console.log(`✓ Fetched ${users.length} users, ${projects.length} projects, ${stages.length} stages`);

    // Create workbook
    const workbook = new ExcelJS.Workbook();

    // Sheet 1: Users
    const usersSheet = addSheetWithHeaders(workbook, 'Users', [
      'user_id',
      'user_name',
      'user_email',
      'global_role',
      'is_active',
      'created_at',
    ]);
    users.forEach((user) => {
      usersSheet.addRow([
        safeValue(user._id?.toString()),
        safeValue(user.name),
        safeValue(user.email),
        safeValue(user.role),
        user.status === 'active' ? 1 : 0,
        safeValue(user.createdAt ? new Date(user.createdAt).toISOString().split('T')[0] : ''),
      ]);
    });

    // Sheet 2: Projects
    const projectsSheet = addSheetWithHeaders(workbook, 'Projects', [
      'project_id',
      'project_no',
      'project_name',
      'project_description',
      'status',
      'priority',
      'start_date',
      'end_date',
      'created_by_user_id',
      'created_at',
      'updated_at',
    ]);
    projects.forEach((project) => {
      projectsSheet.addRow([
        safeValue(project._id?.toString()),
        safeValue(project.project_no),
        safeValue(project.project_name),
        safeValue(project.description),
        safeValue(project.status),
        safeValue(project.priority),
        safeValue(project.start_date ? new Date(project.start_date).toISOString().split('T')[0] : ''),
        safeValue(project.end_date ? new Date(project.end_date).toISOString().split('T')[0] : ''),
        safeValue(project.created_by?._id?.toString()),
        safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split('T')[0] : ''),
        safeValue(project.updatedAt ? new Date(project.updatedAt).toISOString().split('T')[0] : ''),
      ]);
    });

    // Sheet 3: Stages
    const stagesSheet = addSheetWithHeaders(workbook, 'Stages', [
      'stage_id',
      'project_id',
      'stage_number',
      'stage_name',
      'stage_status',
      'approved_by_user_id',
      'approved_at',
      'reverted_count',
      'started_at',
      'ended_at',
    ]);
    stages.forEach((stage) => {
      // stage_number: extract from stage_name (e.g., "Phase 1" -> 1)
      const stageMatch = stage.stage_name?.match(/\d+/);
      const stageNumber = stageMatch ? parseInt(stageMatch[0]) : '';
      
      stagesSheet.addRow([
        safeValue(stage._id?.toString()),
        safeValue(stage.project_id?.toString()),
        safeValue(stageNumber),
        safeValue(stage.stage_name),
        safeValue(stage.status),
        '', // approved_by_user_id - not in current schema
        '', // approved_at - not in current schema
        safeValue(stage.loopback_count || 0),
        '', // started_at - not in current schema
        '', // ended_at - not in current schema
      ]);
    });

    // Sheet 4: ProjectRoles
    const rolesSheet = addSheetWithHeaders(workbook, 'ProjectRoles', [
      'role_id',
      'role_name',
    ]);
    roles.forEach((role) => {
      rolesSheet.addRow([
        safeValue(role._id?.toString()),
        safeValue(role.role_name),
      ]);
    });

    // Sheet 5: ProjectMemberships
    const membershipsSheet = addSheetWithHeaders(workbook, 'ProjectMemberships', [
      'membership_id',
      'project_id',
      'user_id',
      'role_id',
      'assigned_at',
    ]);
    memberships.forEach((membership) => {
      membershipsSheet.addRow([
        safeValue(membership._id?.toString()),
        safeValue(membership.project_id?.toString()),
        safeValue(membership.user_id?._id?.toString()),
        safeValue(membership.role?._id?.toString()),
        safeValue(membership.createdAt ? new Date(membership.createdAt).toISOString().split('T')[0] : ''),
      ]);
    });

    // Note: ChecklistGroups, Sections, Questions sheets would require additional models
    // Currently creating empty sheets with headers for completeness
    
    // Sheet 6: ChecklistGroups (empty - requires ChecklistGroup model)
    addSheetWithHeaders(workbook, 'ChecklistGroups', [
      'group_id',
      'project_id',
      'stage_id',
      'group_name',
      'group_order',
    ]);

    // Sheet 7: Sections (empty - requires Section model)
    addSheetWithHeaders(workbook, 'Sections', [
      'section_id',
      'project_id',
      'stage_id',
      'group_id',
      'section_name',
      'section_order',
    ]);

    // Sheet 8: Questions (empty - requires Question model)
    addSheetWithHeaders(workbook, 'Questions', [
      'question_id',
      'project_id',
      'stage_id',
      'group_id',
      'section_id',
      'question_text',
      'question_order',
    ]);

    // Sheet 9: Checkpoints (FACT TABLE)
    const checkpointsSheet = addSheetWithHeaders(workbook, 'Checkpoints', [
      'checkpoint_id',
      'project_id',
      'stage_id',
      'stage_number',
      'group_id',
      'section_id',
      'question_id',
      'sub_question_text',
      'answered_by_user_id',
      'answered_by_role_id',
      'answer_yes_no',
      'answered_at',
    ]);
    checkpoints.forEach((checkpoint) => {
      checkpointsSheet.addRow([
        safeValue(checkpoint._id?.toString()),
        '', // project_id - need to get from related stage
        '', // stage_id - need to get from related checklist
        '', // stage_number
        '', // group_id
        '', // section_id
        '', // question_id
        safeValue(checkpoint.question),
        '', // answered_by_user_id
        '', // answered_by_role_id
        checkpoint.executorResponse?.answer !== undefined
          ? checkpoint.executorResponse.answer ? 'Yes' : 'No'
          : '',
        safeValue(checkpoint.executorResponse?.respondedAt
          ? new Date(checkpoint.executorResponse.respondedAt).toISOString().split('T')[0]
          : ''),
      ]);
    });

    // Sheet 10: Defects (Derived)
    const defectsSheet = addSheetWithHeaders(workbook, 'Defects', [
      'defect_id',
      'project_id',
      'stage_id',
      'group_id',
      'section_id',
      'question_id',
      'checkpoint_pair_key',
      'reviewer_user_id',
      'executor_user_id',
      'reviewer_answer',
      'executor_answer',
      'is_defect',
      'defect_category',
      'defect_severity',
      'created_at',
    ]);
    // Populate defects by comparing executor and reviewer responses
    checkpoints.forEach((checkpoint, idx) => {
      const executorAnswer = checkpoint.executorResponse?.answer;
      const reviewerAnswer = checkpoint.reviewerResponse?.answer;
      
      if (executorAnswer !== undefined && reviewerAnswer !== undefined) {
        const isDefect = executorAnswer !== reviewerAnswer ? 1 : 0;
        defectsSheet.addRow([
          `defect_${idx}`,
          '', // project_id
          '', // stage_id
          '', // group_id
          '', // section_id
          '', // question_id
          '', // checkpoint_pair_key
          '', // reviewer_user_id
          '', // executor_user_id
          reviewerAnswer ? 'Yes' : 'No',
          executorAnswer ? 'Yes' : 'No',
          isDefect,
          '', // defect_category
          '', // defect_severity
          safeValue(checkpoint.createdAt
            ? new Date(checkpoint.createdAt).toISOString().split('T')[0]
            : ''),
        ]);
      }
    });

    // Sheet 11: ProjectSummary
    const summarySheet = addSheetWithHeaders(workbook, 'ProjectSummary', [
      'project_id',
      'total_checkpoints',
      'total_defects',
      'critical_defects',
      'non_critical_defects',
      'total_reverts',
    ]);
    projects.forEach((project) => {
      const projectCheckpoints = checkpoints.length; // Placeholder
      const projectStages = stages.filter((s) => s.project_id?.toString() === project._id?.toString());
      const totalReverts = projectStages.reduce((sum, s) => sum + (s.loopback_count || 0), 0);

      summarySheet.addRow([
        safeValue(project._id?.toString()),
        projectCheckpoints,
        0, // total_defects - needs full calculation
        0, // critical_defects
        0, // non_critical_defects
        totalReverts,
      ]);
    });

    // Write to buffer
    const buffer = await workbook.xlsx.writeBuffer();

    // Set response headers for download
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="master_export_${new Date().toISOString().split('T')[0]}_${Date.now()}.xlsx"`
    );
    res.setHeader('Content-Length', buffer.length);

    console.log(`✓ Master Excel export completed. File size: ${buffer.length} bytes`);
    res.send(buffer);
  } catch (error) {
    console.error('❌ Export error:', error);
    throw error;
  }
});
