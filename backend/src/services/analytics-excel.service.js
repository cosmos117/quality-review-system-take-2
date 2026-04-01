import prisma from "../config/prisma.js";
import NodeCache from "node-cache";

const _rawCache = new NodeCache({ stdTTL: 30, checkperiod: 10 });
const RAW_CACHE_KEY = "analytics:raw";

export function clearAnalyticsCache() {
  _rawCache.del(RAW_CACHE_KEY);
}

const parseJsonField = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

export async function getRawAnalyticsData() {
  const cached = _rawCache.get(RAW_CACHE_KEY);
  if (cached) return cached;

  const [projects, stages, memberships, templates, projectChecklists] = await Promise.all([
    prisma.project.findMany(),
    prisma.stage.findMany({ select: { id: true, project_id: true, stage_name: true, stage_key: true, status: true, conflict_count: true } }),
    prisma.projectMembership.findMany({ include: { user: { select: { id: true, name: true, email: true } }, role: { select: { role_name: true } } } }),
    prisma.template.findMany({ select: { defectCategories: true } }),
    prisma.projectChecklist.findMany()
  ]);

  const categoryMap = new Map();
  for (const template of templates) {
    const cats = parseJsonField(template.defectCategories);
    for (const cat of cats) {
      if (cat._id && cat.name) {
        categoryMap.set(cat._id.toString(), cat.name);
      }
    }
  }

  const tlMap = new Map();
  const execMap = new Map();

  for (const m of memberships) {
    const roleName = m.role?.role_name?.toLowerCase() ?? "";
    const pid = m.project_id;
    const name = m.user?.name ?? "";
    if (!pid || !name) continue;

    if (roleName.includes("teamleader")) {
      if (!tlMap.has(pid)) tlMap.set(pid, []);
      tlMap.get(pid).push(name);
    }

    if (roleName.includes("executor")) {
      if (!execMap.has(pid)) execMap.set(pid, []);
      execMap.get(pid).push(name);
    }
  }

  const allExecutorsSet = new Set();
  const executorNamesToIgnore = new Set(["na", "-"]);

  for (const executorList of execMap.values()) {
    for (const rawNames of executorList) {
      const names = rawNames.split(/[,/;\n]/).map((n) => n.trim()).filter((n) => n.length > 0);
      for (const name of names) {
        const lowerName = name.toLowerCase();
        if (executorNamesToIgnore.has(lowerName)) continue;
        allExecutorsSet.add(name);
      }
    }
  }

  const summaryRows = projects.map((p) => {
    const pid = p.id;
    const teamLeaders = tlMap.get(pid) ?? [];
    const projectExecutors = (execMap.get(pid) ?? []).join(", ");

    return {
      projectNumber: p.project_no ?? "",
      projectName: p.project_name ?? "",
      teamLeaders,
      overallDR: p.overallDefectRate ?? null,
      status: p.status ?? "",
      executors: projectExecutors,
    };
  });

  const detailRows = [];

  for (const project of projects) {
    if (project.isReviewApplicable === "no") continue;

    const pid = project.id;
    const teamLeader = (tlMap.get(pid) ?? []).join(", ");
    const projectExecutors = (execMap.get(pid) ?? []).join(", ");

    const projectStages = stages.filter((s) => s.project_id === pid);
    const checklistDocs = projectChecklists.filter((pc) => pc.projectId === pid);
    
    if (!checklistDocs.length) continue;

    for (const stage of projectStages) {
      const sid = stage.id;
      const phaseMatch = stage.stage_name?.match(/\d+/);
      const phaseNumber = phaseMatch ? parseInt(phaseMatch[0], 10) : 0;

      const checklistDoc = checklistDocs.find((pc) => pc.stageId === sid);
      if (!checklistDoc) continue;

      const groups = parseJsonField(checklistDoc.groups);
      const iterations = parseJsonField(checklistDoc.iterations);

      // Simple internal cache for user names to avoid making thousands of queries inside this loop 
      // if storing user reference in answeredBy instead of string Name
      const processQuestion = (question) => {
        // Find executor by id assuming stored in answeredBy.executor
        // In this particular logic we do not have populate, 
        // if user name is not directly stored we'd fallback. Since the earlier migration set user ID, it's ok.
        const fallbackName = ""; 
        const questionExecutor = fallbackName;
        
        const finalExecutor = questionExecutor.trim() ? questionExecutor : projectExecutors;
        const executor = finalExecutor.trim() || "-";

        const rawCatId = question.categoryId || "";
        const defectCategory = rawCatId ? (categoryMap.get(rawCatId.toString()) ?? "") : "";

        if (!defectCategory.trim()) return;

        detailRows.push({
          projectNumber: project.project_no ?? "",
          projectName: project.project_name ?? "",
          teamLeader,
          executor,
          phase: phaseNumber,
          defectCategory,
          defectSeverity: question.severity ?? "",
          reviewerRemark: question.reviewerRemark ?? "",
        });
      };

      for (const group of groups ?? []) {
        (group.questions ?? []).forEach(processQuestion);
        for (const section of group.sections ?? []) {
          (section.questions ?? []).forEach(processQuestion);
        }
      }

      for (const iteration of iterations ?? []) {
        for (const group of iteration.groups ?? []) {
          (group.questions ?? []).forEach(processQuestion);
          for (const section of group.sections ?? []) {
            (section.questions ?? []).forEach(processQuestion);
          }
        }
      }
    }
  }

  const result = {
    summaryRows,
    detailRows,
    allExecutors: Array.from(allExecutorsSet).sort(),
  };
  _rawCache.set(RAW_CACHE_KEY, result);
  return result;
}

function normStr(s) {
  return (s ?? "").toLowerCase().trim();
}

function filterRows(detailRows, summaryRows, { teamLeader, project, defectCategory, executor }) {
  let dr = detailRows;
  let sr = summaryRows;

  if (teamLeader) {
    const tl = normStr(teamLeader);
    dr = dr.filter((r) => r.teamLeader.split(",").map((t) => t.trim().toLowerCase()).some((t) => t === tl || t.includes(tl)));
    sr = sr.filter((r) => r.teamLeaders.map((t) => t.toLowerCase()).some((t) => t === tl || t.includes(tl)));
  }

  if (project) {
    const pn = normStr(project);
    dr = dr.filter((r) => normStr(r.projectName) === pn || normStr(r.projectNumber) === pn || normStr(r.projectName).includes(pn) || normStr(r.projectNumber).includes(pn));
    sr = sr.filter((r) => normStr(r.projectName) === pn || normStr(r.projectNumber) === pn || normStr(r.projectName).includes(pn) || normStr(r.projectNumber).includes(pn));
  }

  if (defectCategory) {
    const dc = normStr(defectCategory);
    dr = dr.filter((r) => normStr(r.defectCategory) === dc);
  }

  if (executor) {
    const exc = normStr(executor);
    dr = dr.filter((r) => normStr(r.executor) === exc);
  }

  return { dr, sr };
}

export function computeAnalytics(summaryRows, detailRows, filters = {}) {
  const { teamLeader = null, project = null, defectCategory = null, executor = null, page = 1, limitNum = 20, search = "" } = filters;
  const { dr: filtered, sr: filteredSummary } = filterRows(detailRows, summaryRows, { teamLeader, project, defectCategory, executor });

  const projectNames = new Set(filteredSummary.map((r) => r.projectName || r.projectNumber));
  const totalProjects = projectNames.size;
  const rates = filteredSummary.map((r) => r.overallDR).filter((r) => r !== null && r !== undefined && !Number.isNaN(r));
  const averageDefectRate = rates.length ? parseFloat((rates.reduce((a, b) => a + b, 0) / rates.length).toFixed(2)) : 0;
  const maxDefectRate = rates.length ? parseFloat(Math.max(...rates).toFixed(2)) : 0;

  const catCounts = {};
  for (const r of filtered) {
    if (r.defectCategory) catCounts[r.defectCategory] = (catCounts[r.defectCategory] ?? 0) + 1;
  }
  const allDefectCategories = Object.entries(catCounts).map(([category, count]) => ({ category, count })).sort((a, b) => b.count - a.count);
  const topDefectCategories = allDefectCategories.slice(0, 5);

  const sevCounts = {};
  for (const r of filtered) {
    if (r.defectSeverity) sevCounts[r.defectSeverity] = (sevCounts[r.defectSeverity] ?? 0) + 1;
  }
  const severityDistribution = Object.entries(sevCounts).map(([severity, count]) => ({ severity, count }));

  const projectDrMap = {};
  for (const r of filteredSummary) {
    if (r.overallDR !== null && r.overallDR !== undefined) {
      const key = r.projectName || r.projectNumber || "Unknown";
      if (!(key in projectDrMap)) projectDrMap[key] = r.overallDR;
    }
  }
  const drByProject = Object.entries(projectDrMap).map(([proj, defectRate]) => ({ project: proj, defectRate: parseFloat(defectRate.toFixed(2)) })).sort((a, b) => b.defectRate - a.defectRate).slice(0, 10);

  const tlDrMap = {};
  for (const r of filteredSummary) {
    for (const tl of r.teamLeaders) {
      if (!tl) continue;
      if (!tlDrMap[tl]) tlDrMap[tl] = [];
      if (r.overallDR !== null && r.overallDR !== undefined) tlDrMap[tl].push(r.overallDR);
    }
  }
  const drByTeamLeader = Object.entries(tlDrMap)
    .filter(([, rts]) => rts.length > 0)
    .map(([tl, rts]) => ({
      teamLeader: tl,
      avgDR: parseFloat((rts.reduce((a, b) => a + b, 0) / rts.length).toFixed(2)),
      projectCount: rts.length,
    }))
    .sort((a, b) => b.avgDR - a.avgDR);

  let tableRows = filtered;
  if (search.trim()) {
    const s = search.toLowerCase();
    tableRows = tableRows.filter((r) => r.projectNumber.toLowerCase().includes(s) || r.projectName.toLowerCase().includes(s) || r.teamLeader.toLowerCase().includes(s));
  }

  const total = tableRows.length;
  const safePage = Math.max(1, page);
  const safeLimit = Math.max(1, Math.min(100, limitNum));
  const paged = tableRows.slice((safePage - 1) * safeLimit, safePage * safeLimit).map((r) => ({
    project_number: r.projectNumber,
    project_name: r.projectName,
    team_leader: r.teamLeader,
    executor: r.executor,
    defect_category: r.defectCategory,
    defect_severity: r.defectSeverity,
    reviewer_remark: r.reviewerRemark,
  }));

  return {
    summary: { totalProjects, averageDefectRate, maxDefectRate },
    allDefectCategories,
    topDefectCategories,
    severityDistribution,
    drByProject,
    drByTeamLeader,
    defectDetails: { data: paged, total, page: safePage, limit: safeLimit },
  };
}

export function getTeamLeadersList(summaryRows) {
  const set = new Set();
  for (const r of summaryRows) {
    for (const tl of r.teamLeaders) if (tl) set.add(tl);
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
  return summaryRows.filter((r) => r.projectName || r.projectNumber).map((r) => ({
    name: r.projectName, no: r.projectNumber, id: r.projectName || r.projectNumber,
  }));
}

export function getExecutorsList(detailRows) {
  const set = new Set();
  for (const r of detailRows) {
    if (r.executor && r.executor.trim()) set.add(r.executor);
  }
  return [...set].sort();
}
