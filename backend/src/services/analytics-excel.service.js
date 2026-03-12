/**
 * Analytics Excel Service
 *
 * Builds the analytics dataset from the exact same data source used
 * by the master Excel export (ProjectChecklist + Project + Stage + Template).
 * This guarantees that the dashboard always shows data consistent with
 * the exported Excel report.
 */

import mongoose from "mongoose";
import { Role } from "../models/roles.models.js";
import Project from "../models/project.models.js";
import Stage from "../models/stage.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import NodeCache from "node-cache";

// Cache the raw dataset for 30 seconds so multiple concurrent requests
// from the same page load don't hammer the DB.
const _rawCache = new NodeCache({ stdTTL: 30, checkperiod: 10 });
const RAW_CACHE_KEY = "analytics:raw";

// ─── Raw data types (JSDoc only, no TypeScript) ───────────────────────────────
// summaryRow: { projectNumber, projectName, teamLeaders:string[], overallDR:number|null, status }
// detailRow:  { projectNumber, projectName, teamLeader:string, phase:number,
//               defectCategory:string, defectSeverity:string, reviewerRemark:string }

// ─────────────────────────────────────────────────────────────────────────────
// Raw data extraction  (mirrors generateMasterExcel data gathering)
// ─────────────────────────────────────────────────────────────────────────────

export async function getRawAnalyticsData() {
  const cached = _rawCache.get(RAW_CACHE_KEY);
  if (cached) return cached;

  // Same queries as generateMasterExcel
  const [projects, stages, memberships, templates, projectChecklists] =
    await Promise.all([
      Project.find().lean(),
      Stage.find(
        {},
        "_id project_id stage_name stage_key status conflict_count",
      ).lean(),
      ProjectMembership.find()
        .populate("user_id", "name email _id")
        .populate("role", "role_name")
        .lean(),
      mongoose.model("Template").find({}, "defectCategories").lean(),
      mongoose.model("ProjectChecklist").find().lean(),
    ]);

  // Build category ID → name lookup (same as export service)
  const categoryMap = new Map();
  for (const template of templates) {
    for (const cat of template.defectCategories ?? []) {
      if (cat._id && cat.name) {
        categoryMap.set(cat._id.toString(), cat.name);
      }
    }
  }

  // Build project → team leader array map
  const tlMap = new Map(); // projectId → string[]
  for (const m of memberships) {
    const roleName = m.role?.role_name?.toLowerCase() ?? "";
    if (!roleName.includes("teamleader")) continue;
    const pid = m.project_id?.toString();
    const name = m.user_id?.name ?? "";
    if (!pid || !name) continue;
    if (!tlMap.has(pid)) tlMap.set(pid, []);
    tlMap.get(pid).push(name);
  }

  // ── Summary rows (one per project) ────────────────────────────────────────
  const summaryRows = projects.map((p) => {
    const pid = p._id?.toString();
    return {
      projectNumber: p.project_no ?? "",
      projectName: p.project_name ?? "",
      teamLeaders: tlMap.get(pid) ?? [],
      overallDR: p.overallDefectRate ?? null,
      status: p.status ?? "",
    };
  });

  // ── Detail rows (one per question with a defect category) ─────────────────
  const detailRows = [];

  for (const project of projects) {
    if (project.isReviewApplicable === "no") continue;

    const pid = project._id?.toString();
    const teamLeader = (tlMap.get(pid) ?? []).join(", ");

    const projectStages = stages.filter(
      (s) => s.project_id?.toString() === pid,
    );
    const checklistDocs = projectChecklists.filter(
      (pc) => pc.projectId?.toString() === pid,
    );
    if (!checklistDocs.length) continue;

    for (const stage of projectStages) {
      const sid = stage._id?.toString();
      const phaseMatch = stage.stage_name?.match(/\d+/);
      const phaseNumber = phaseMatch ? parseInt(phaseMatch[0], 10) : 0;

      const checklistDoc = checklistDocs.find(
        (pc) => pc.stageId?.toString() === sid,
      );
      if (!checklistDoc) continue;

      const pushQuestion = (question) => {
        const rawCatId = question.categoryId?.toString() ?? "";
        const defectCategory = rawCatId
          ? categoryMap.get(rawCatId) ?? ""
          : "";

        if (!defectCategory.trim()) return; // skip rows with no category (not defects)

        detailRows.push({
          projectNumber: project.project_no ?? "",
          projectName: project.project_name ?? "",
          teamLeader,
          phase: phaseNumber,
          defectCategory,
          defectSeverity: question.severity ?? "",
          reviewerRemark: question.reviewerRemark ?? "",
        });
      };

      for (const group of checklistDoc.groups ?? []) {
        (group.questions ?? []).forEach(pushQuestion);
        for (const section of group.sections ?? []) {
          (section.questions ?? []).forEach(pushQuestion);
        }
      }
    }
  }

  const result = { summaryRows, detailRows };
  _rawCache.set(RAW_CACHE_KEY, result);
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter helpers
// ─────────────────────────────────────────────────────────────────────────────

function normStr(s) {
  return (s ?? "").toLowerCase().trim();
}

function filterRows(detailRows, summaryRows, { teamLeader, project, defectCategory }) {
  let dr = detailRows;
  let sr = summaryRows;

  if (teamLeader) {
    const tl = normStr(teamLeader);
    dr = dr.filter((r) =>
      r.teamLeader
        .split(",")
        .map((t) => t.trim().toLowerCase())
        .some((t) => t === tl || t.includes(tl)),
    );
    sr = sr.filter((r) =>
      r.teamLeaders
        .map((t) => t.toLowerCase())
        .some((t) => t === tl || t.includes(tl)),
    );
  }

  if (project) {
    const pn = normStr(project);
    dr = dr.filter(
      (r) =>
        normStr(r.projectName) === pn ||
        normStr(r.projectNumber) === pn ||
        normStr(r.projectName).includes(pn) ||
        normStr(r.projectNumber).includes(pn),
    );
    sr = sr.filter(
      (r) =>
        normStr(r.projectName) === pn ||
        normStr(r.projectNumber) === pn ||
        normStr(r.projectName).includes(pn) ||
        normStr(r.projectNumber).includes(pn),
    );
  }

  if (defectCategory) {
    const dc = normStr(defectCategory);
    dr = dr.filter((r) => normStr(r.defectCategory) === dc);
    // defectCategory filter does not restrict summary rows (KPIs stay project-level)
  }

  return { dr, sr };
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics computation
// ─────────────────────────────────────────────────────────────────────────────

export function computeAnalytics(summaryRows, detailRows, filters = {}) {
  const {
    teamLeader = null,
    project = null,
    defectCategory = null,
    page = 1,
    limitNum = 20,
    search = "",
  } = filters;

  const { dr: filtered, sr: filteredSummary } = filterRows(
    detailRows,
    summaryRows,
    { teamLeader, project, defectCategory },
  );

  // ── KPI summary ─────────────────────────────────────────────────────────
  const projectNames = new Set(filteredSummary.map((r) => r.projectName || r.projectNumber));
  const totalProjects = projectNames.size;
  const rates = filteredSummary
    .map((r) => r.overallDR)
    .filter((r) => r !== null && r !== undefined && !Number.isNaN(r));
  const averageDefectRate = rates.length
    ? parseFloat((rates.reduce((a, b) => a + b, 0) / rates.length).toFixed(2))
    : 0;
  const maxDefectRate = rates.length
    ? parseFloat(Math.max(...rates).toFixed(2))
    : 0;

  // ── Top defect categories (top 5) ────────────────────────────────────────
  const catCounts = {};
  for (const r of filtered) {
    if (r.defectCategory) {
      catCounts[r.defectCategory] = (catCounts[r.defectCategory] ?? 0) + 1;
    }
  }
  const topDefectCategories = Object.entries(catCounts)
    .map(([category, count]) => ({ category, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  // ── Severity distribution ─────────────────────────────────────────────────
  const sevCounts = {};
  for (const r of filtered) {
    if (r.defectSeverity) {
      sevCounts[r.defectSeverity] = (sevCounts[r.defectSeverity] ?? 0) + 1;
    }
  }
  const severityDistribution = Object.entries(sevCounts).map(
    ([severity, count]) => ({ severity, count }),
  );

  // ── DR by project (top 10) ────────────────────────────────────────────────
  const projectDrMap = {};
  for (const r of filteredSummary) {
    if (r.overallDR !== null && r.overallDR !== undefined) {
      const key = r.projectName || r.projectNumber || "Unknown";
      // keep the first occurrence (each project appears once in summaryRows)
      if (!(key in projectDrMap)) {
        projectDrMap[key] = r.overallDR;
      }
    }
  }
  const drByProject = Object.entries(projectDrMap)
    .map(([proj, defectRate]) => ({
      project: proj,
      defectRate: parseFloat(defectRate.toFixed(2)),
    }))
    .sort((a, b) => b.defectRate - a.defectRate)
    .slice(0, 10);

  // ── DR by team leader ─────────────────────────────────────────────────────
  const tlDrMap = {};
  for (const r of filteredSummary) {
    for (const tl of r.teamLeaders) {
      if (!tl) continue;
      if (!tlDrMap[tl]) tlDrMap[tl] = [];
      if (r.overallDR !== null && r.overallDR !== undefined) {
        tlDrMap[tl].push(r.overallDR);
      }
    }
  }
  const drByTeamLeader = Object.entries(tlDrMap)
    .filter(([, rts]) => rts.length > 0)
    .map(([tl, rts]) => ({
      teamLeader: tl,
      avgDR: parseFloat(
        (rts.reduce((a, b) => a + b, 0) / rts.length).toFixed(2),
      ),
      projectCount: rts.length,
    }))
    .sort((a, b) => b.avgDR - a.avgDR);

  // ── Defect details table (search + pagination) ────────────────────────────
  let tableRows = filtered;
  if (search.trim()) {
    const s = search.toLowerCase();
    tableRows = tableRows.filter(
      (r) =>
        r.projectNumber.toLowerCase().includes(s) ||
        r.projectName.toLowerCase().includes(s) ||
        r.teamLeader.toLowerCase().includes(s) ||
        r.defectCategory.toLowerCase().includes(s) ||
        r.defectSeverity.toLowerCase().includes(s) ||
        r.reviewerRemark.toLowerCase().includes(s),
    );
  }

  const total = tableRows.length;
  const safePage = Math.max(1, page);
  const safeLimit = Math.max(1, Math.min(100, limitNum));
  const paged = tableRows
    .slice((safePage - 1) * safeLimit, safePage * safeLimit)
    .map((r) => ({
      project_number: r.projectNumber,
      project_name: r.projectName,
      team_leader: r.teamLeader,
      defect_category: r.defectCategory,
      defect_severity: r.defectSeverity,
      reviewer_remark: r.reviewerRemark,
    }));

  return {
    summary: { totalProjects, averageDefectRate, maxDefectRate },
    topDefectCategories,
    severityDistribution,
    drByProject,
    drByTeamLeader,
    defectDetails: {
      data: paged,
      total,
      page: safePage,
      limit: safeLimit,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown list helpers
// ─────────────────────────────────────────────────────────────────────────────

export function getTeamLeadersList(summaryRows) {
  const set = new Set();
  for (const r of summaryRows) {
    for (const tl of r.teamLeaders) {
      if (tl) set.add(tl);
    }
  }
  return [...set].sort();
}

export function getDefectCategoriesList(detailRows) {
  const set = new Set();
  for (const r of detailRows) {
    if (r.defectCategory) set.add(r.defectCategory);
  }
  return [...set].sort();
}

export function getProjectsList(summaryRows) {
  return summaryRows
    .filter((r) => r.projectName || r.projectNumber)
    .map((r) => ({
      name: r.projectName,
      no: r.projectNumber,
      id: r.projectName || r.projectNumber, // use name as display key
    }));
}
