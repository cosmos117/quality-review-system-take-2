import ExcelJS from "exceljs";
import prisma from "../config/prisma.js";

const parseJsonField = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

const safeValue = (val, defaultVal = "") => {
  if (val === null || val === undefined) return defaultVal;
  if (typeof val === "boolean") return val;
  return val;
};

export const generateMasterExcel = async () => {
  const [users, projects, stages, roles, memberships, templates, projectChecklists] = await Promise.all([
    prisma.user.findMany({ select: { id: true, name: true, email: true } }),
    prisma.project.findMany({ include: { creator: { select: { name: true, email: true } } } }),
    prisma.stage.findMany({ select: { id: true, project_id: true, stage_name: true, stage_key: true, status: true, conflict_count: true } }),
    prisma.role.findMany({ select: { id: true, role_name: true } }),
    prisma.projectMembership.findMany({ include: { user: { select: { id: true, name: true, email: true } }, role: { select: { role_name: true } } } }),
    prisma.template.findMany({ select: { defectCategories: true } }),
    prisma.projectChecklist.findMany(),
  ]);

  const categoryMap = new Map();
  if (templates && templates.length > 0) {
    templates.forEach((template) => {
      const defectCategories = parseJsonField(template.defectCategories);
      defectCategories.forEach((cat) => {
        if (cat._id && cat.name) {
          categoryMap.set(cat._id.toString(), cat.name);
        }
      });
    });
  }

  const projectExecutorsMap = new Map();
  const projectReviewersMap = new Map();
  const projectTeamLeadersMap = new Map();

  memberships.forEach((membership) => {
    const projectId = membership.project_id;
    const userName = membership.user?.name || "";
    const roleName = membership.role?.role_name?.toLowerCase() || "";
    if (!userName) return;

    if (roleName.includes("executor")) {
      if (!projectExecutorsMap.has(projectId)) projectExecutorsMap.set(projectId, []);
      projectExecutorsMap.get(projectId).push(userName);
    } else if (roleName.includes("reviewer")) {
      if (!projectReviewersMap.has(projectId)) projectReviewersMap.set(projectId, []);
      projectReviewersMap.get(projectId).push(userName);
    } else if (roleName.includes("teamleader")) {
      if (!projectTeamLeadersMap.has(projectId)) projectTeamLeadersMap.set(projectId, []);
      projectTeamLeadersMap.get(projectId).push(userName);
    }
  });

  const workbook = new ExcelJS.Workbook();

  // ===== Sheet 1: Project Summary =====
  const summarySheet = workbook.addWorksheet("Project Summary");
  const summaryHeaders = [
    "Year", "Project Number", "Project Name", "Created Date", "Team Leaders",
    "Executors", "Reviewers", "Is Review Applicable", "Overall Defect Rate (%)",
    "Project Status", "Total Phases", "Created By",
  ];

  const summaryHeaderRow = summarySheet.addRow(summaryHeaders);
  summaryHeaderRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF366092" } };
    cell.alignment = { horizontal: "center", vertical: "center", wrapText: true };
  });

  summarySheet.columns = [
    { width: 10 }, { width: 25 }, { width: 50 }, { width: 18 }, { width: 30 },
    { width: 30 }, { width: 30 }, { width: 20 }, { width: 22 }, { width: 15 },
    { width: 15 }, { width: 20 },
  ];

  // ===== Sheet 2: Questions & Answers =====
  const detailSheet = workbook.addWorksheet("Questions & Answers");
  const detailHeaders = [
    "Year", "Project Number", "Project Name", "Created Date", "Project Status",
    "Phase", "Checklist Group", "Section", "Question", "Executor Remark",
    "Reviewer Remark", "Defect Category", "Defect Severity", "Phase Conflict Count",
  ];

  const detailHeaderRow = detailSheet.addRow(detailHeaders);
  detailHeaderRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF366092" } };
    cell.alignment = { horizontal: "center", vertical: "center", wrapText: true };
  });

  detailSheet.columns = [
    { width: 10 }, { width: 25 }, { width: 50 }, { width: 18 }, { width: 15 },
    { width: 10 }, { width: 30 }, { width: 30 }, { width: 60 }, { width: 40 },
    { width: 40 }, { width: 40 }, { width: 18 }, { width: 18 },
  ];

  // ===== Sheet 3: Employee Performance =====
  const employeeSheet = workbook.addWorksheet("Employee Performance");
  const employeeHeaders = [
    "Employee Name", "Email", "Completed Projects", "Ongoing Projects",
    "Total Assigned Projects", "Average Defect Rate (%)",
  ];

  const employeeHeaderRow = employeeSheet.addRow(employeeHeaders);
  employeeHeaderRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF366092" } };
    cell.alignment = { horizontal: "center", vertical: "center", wrapText: true };
  });

  employeeSheet.columns = [
    { width: 30 }, { width: 35 }, { width: 20 }, { width: 20 },
    { width: 25 }, { width: 22 },
  ];

  const employeePerformanceMap = new Map();

  memberships.forEach((membership) => {
    const userId = membership.user_id;
    const userName = membership.user?.name || "";
    const userEmail = membership.user?.email || "";
    const projectId = membership.project_id;
    const roleName = membership.role?.role_name || "";
    if (!userId || !userName || !projectId) return;

    const project = projects.find((p) => p.id === projectId);
    if (!project) return;

    if (!employeePerformanceMap.has(userId)) {
      employeePerformanceMap.set(userId, {
        name: userName, email: userEmail,
        completedProjects: new Set(), ongoingProjects: new Set(),
        totalProjects: new Set(), teamLeaderProjects: [],
      });
    }

    const empData = employeePerformanceMap.get(userId);
    empData.totalProjects.add(projectId);

    const status = project.status?.toLowerCase() || "";
    if (status === "completed") {
      empData.completedProjects.add(projectId);
    } else {
      empData.ongoingProjects.add(projectId);
    }

    if (roleName === "TeamLeader" && !empData.teamLeaderProjects.some(p => p.projectId === projectId)) {
      empData.teamLeaderProjects.push({ projectId, defectRate: project.overallDefectRate });
    }
  });

  employeePerformanceMap.forEach((empData) => {
    const validRates = empData.teamLeaderProjects.filter((p) => p.defectRate !== null && p.defectRate !== undefined);
    const avgDefectRate = validRates.length > 0 ? (validRates.reduce((sum, p) => sum + p.defectRate, 0) / validRates.length).toFixed(2) : "";

    employeeSheet.addRow([
      safeValue(empData.name), safeValue(empData.email),
      empData.completedProjects.size, empData.ongoingProjects.size,
      empData.totalProjects.size, safeValue(avgDefectRate),
    ]);
  });

  // ===== Process each project =====
  for (const project of projects) {
    if (project.isReviewApplicable === "no") continue;

    const projectId = project.id;
    const year = project.project_no ? project.project_no.substring(0, 4) : "";

    const projectStages = stages
      .filter((s) => s.project_id === projectId)
      .sort((a, b) => {
        const aNum = parseInt(a.stage_name?.match(/\d+/)?.[0] || "0");
        const bNum = parseInt(b.stage_name?.match(/\d+/)?.[0] || "0");
        return aNum - bNum;
      });

    const executorsStr = (projectExecutorsMap.get(projectId) || []).join(", ");
    const reviewersStr = (projectReviewersMap.get(projectId) || []).join(", ");
    const teamLeadersStr = (projectTeamLeadersMap.get(projectId) || []).join(", ");

    const isReviewApplicable = project.isReviewApplicable === null || project.isReviewApplicable === undefined ? "" : project.isReviewApplicable === "yes" ? "Yes" : "No";
    const overallDefectRate = project.overallDefectRate !== null && project.overallDefectRate !== undefined ? project.overallDefectRate.toFixed(2) : "";

    summarySheet.addRow([
      safeValue(year), safeValue(project.project_no || ""), safeValue(project.project_name),
      safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split("T")[0] : ""),
      safeValue(teamLeadersStr), safeValue(executorsStr), safeValue(reviewersStr),
      safeValue(isReviewApplicable), safeValue(overallDefectRate), safeValue(project.status),
      safeValue(projectStages.length),
      safeValue(project.creator?.name || project.creator?.email || ""),
    ]);

    const projectChecklistDocs = projectChecklists.filter((pc) => pc.projectId === projectId);

    if (projectChecklistDocs.length === 0) {
      detailSheet.addRow([
        safeValue(year), safeValue(project.project_no || ""), safeValue(project.project_name),
        safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split("T")[0] : ""),
        safeValue(project.status), "", "", "", "No checklist data available", "", "", "", "", "",
      ]);
      continue;
    }

    for (const stage of projectStages) {
      const stageId = stage.id;
      const phaseMatch = stage.stage_name?.match(/\d+/);
      const phaseNumber = phaseMatch ? parseInt(phaseMatch[0]) : 0;

      const projectChecklistDoc = projectChecklistDocs.find((pc) => pc.stageId === stageId);
      if (!projectChecklistDoc) continue;

      const groups = parseJsonField(projectChecklistDoc.groups);
      
      if (groups.length === 0) {
        detailSheet.addRow([
          safeValue(year), safeValue(project.project_no || ""), safeValue(project.project_name),
          safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split("T")[0] : ""),
          safeValue(project.status), safeValue(phaseNumber), "", "",
          "No questions in this phase", "", "", "", "", safeValue(stage.conflict_count ?? 0),
        ]);
        continue;
      }

      groups.forEach((group) => {
        const groupName = group.groupName || "";

        if (group.questions && Array.isArray(group.questions)) {
          group.questions.forEach((question) => {
            const categoryName = question.categoryId ? categoryMap.get(question.categoryId.toString()) || `[Unknown: ${question.categoryId}]` : "";
            detailSheet.addRow([
              safeValue(year), safeValue(project.project_no || ""), safeValue(project.project_name),
              safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split("T")[0] : ""),
              safeValue(project.status), safeValue(phaseNumber), safeValue(groupName), "",
              safeValue(question.text || ""), safeValue(question.executorRemark || ""),
              safeValue(question.reviewerRemark || ""), safeValue(categoryName),
              safeValue(question.severity || ""), safeValue(stage.conflict_count ?? 0),
            ]);
          });
        }

        if (group.sections && Array.isArray(group.sections)) {
          group.sections.forEach((section) => {
            const sectionName = section.sectionName || "";
            if (section.questions && Array.isArray(section.questions)) {
              section.questions.forEach((question) => {
                const categoryName = question.categoryId ? categoryMap.get(question.categoryId.toString()) || `[Unknown: ${question.categoryId}]` : "";
                detailSheet.addRow([
                  safeValue(year), safeValue(project.project_no || ""), safeValue(project.project_name),
                  safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split("T")[0] : ""),
                  safeValue(project.status), safeValue(phaseNumber), safeValue(groupName),
                  safeValue(sectionName), safeValue(question.text || ""),
                  safeValue(question.executorRemark || ""), safeValue(question.reviewerRemark || ""),
                  safeValue(categoryName), safeValue(question.severity || ""),
                  safeValue(stage.conflict_count ?? 0),
                ]);
              });
            }
          });
        }
      });
    }
  }

  // ===== Sheet 4: Review Not Applicable =====
  const notApplicableSheet = workbook.addWorksheet("Review Not Applicable");
  const notApplicableHeaders = [
    "Year", "Project Number", "Project Name", "Created Date",
    "Project Status", "Priority", "Created By", "Remark (Why Not Applicable)",
  ];

  const notApplicableHeaderRow = notApplicableSheet.addRow(notApplicableHeaders);
  notApplicableHeaderRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE74C3C" } };
    cell.alignment = { horizontal: "center", vertical: "center", wrapText: true };
  });

  notApplicableSheet.columns = [
    { width: 10 }, { width: 25 }, { width: 50 }, { width: 18 },
    { width: 15 }, { width: 15 }, { width: 20 }, { width: 60 },
  ];

  const notApplicableProjects = projects.filter((p) => p.isReviewApplicable === "no");

  for (const project of notApplicableProjects) {
    const year = project.project_no ? project.project_no.substring(0, 4) : "";

    const statusDisplay = project.status === "in_progress" ? "In Progress" : project.status === "completed" ? "Completed" : project.status === "pending" ? "Not Started" : project.status;
    const priorityDisplay = project.priority === "high" ? "High" : project.priority === "low" ? "Low" : project.priority === "medium" ? "Medium" : project.priority;

    notApplicableSheet.addRow([
      safeValue(year), safeValue(project.project_no || ""), safeValue(project.project_name),
      safeValue(project.createdAt ? new Date(project.createdAt).toISOString().split("T")[0] : ""),
      safeValue(statusDisplay), safeValue(priorityDisplay),
      safeValue(project.creator?.name || project.creator?.email || ""),
      safeValue(project.reviewApplicableRemark || "No remark provided"),
    ]);
  }

  const buffer = await workbook.xlsx.writeBuffer();
  return buffer;
};
