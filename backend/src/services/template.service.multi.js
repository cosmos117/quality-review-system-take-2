import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { getOrSet, keys, TTL, invalidateTemplate } from "../utils/cache.js";
import { newId } from "../utils/newId.js";

const isValidStage = (stage) => /^stage\d{1,2}$/.test(stage);

const parseJsonField = (field) => {
    if (!field) return {};
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

const parseJsonArray = (field) => {
    if (!field) return [];
    if (typeof field === 'string') return JSON.parse(field);
    return field;
};

async function ensureTemplateConsistency(template) {
  let modified = false;
  const stageData = parseJsonField(template.stageData);
  const stageKeys = Object.keys(stageData).filter((k) => /^stage\d{1,2}$/.test(k));

  for (const stage of stageKeys) {
    const arr = stageData[stage];
    if (!Array.isArray(arr)) continue;
    arr.forEach((cl) => {
      if (!cl._id) {
        cl._id = newId();
        modified = true;
      }
      if (!Array.isArray(cl.checkpoints)) {
        cl.checkpoints = [];
        modified = true;
      }
      if (!Array.isArray(cl.sections)) {
        cl.sections = [];
        modified = true;
      }
      cl.sections.forEach((sec) => {
        if (!sec._id) {
          sec._id = newId();
          modified = true;
        }
        if (!Array.isArray(sec.checkpoints)) {
          sec.checkpoints = [];
          modified = true;
        }
        sec.checkpoints.forEach((cp) => {
          if (!cp._id) {
            cp._id = newId();
            modified = true;
          }
        });
      });
      cl.checkpoints.forEach((cp) => {
        if (!cp._id) {
          cp._id = newId();
          modified = true;
        }
      });
    });
  }
  
  if (modified) {
    template.stageData = stageData;
  }
  return modified;
}

async function getTemplateByName(templateName) {
  const template = await prisma.template.findFirst({ where: { templateName } });
  if (!template) throw new ApiError(404, `Template "${templateName}" not found`);
  return template;
}

function validateStage(stage) {
  if (!isValidStage(stage)) throw new ApiError(400, "Invalid stage format. Must be stage1-99");
}

function findChecklist(stageData, stage, checklistId) {
  if (!Array.isArray(stageData[stage])) {
    throw new ApiError(404, `Stage ${stage} not found or has no checklists`);
  }
  const checklist = stageData[stage].find(item => item._id === checklistId);
  if (!checklist) throw new ApiError(404, "Checklist not found in specified stage");
  return checklist;
}

function findSection(checklist, sectionId) {
  const section = checklist.sections?.find((item) => item._id === sectionId);
  if (!section) throw new ApiError(404, "Section not found in this checklist");
  return section;
}

// ── Template CRUD ──

export async function createTemplate(templateName, displayName, description, userId) {
  if (!templateName || !templateName.trim()) {
    throw new ApiError(400, "templateName is required");
  }

  const existing = await prisma.template.findFirst({
    where: { templateName: templateName.trim() },
  });
  if (existing) {
    throw new ApiError(409, `Template with name "${templateName}" already exists`);
  }

  const template = await prisma.template.create({
    data: {
      id: newId(),
      templateName: templateName.trim(),
      name: displayName || templateName.trim(),
      description: description || "",
      modifiedBy: userId,
      stageData: {},
      stageNames: {},
      defectCategories: []
    }
  });

  invalidateTemplate();
  return template;
}

export async function saveTemplatePayload(templateName, displayName, description, templateData, userId) {
  const normalizedTemplateName = (templateName || "").trim();
  if (!normalizedTemplateName) {
    throw new ApiError(400, "templateName is required");
  }

  const existing = await prisma.template.findFirst({
    where: { templateName: normalizedTemplateName },
  });
  if (existing) {
    throw new ApiError(409, `Template with name "${normalizedTemplateName}" already exists`);
  }

  const stageData = {};
  for (const [key, value] of Object.entries(templateData)) {
    if (/^stage\d{1,2}$/.test(key) && Array.isArray(value)) {
      stageData[key] = value;
    }
  }

  let stageNames = {};
  if (templateData.stageNames && typeof templateData.stageNames === "object" && !Array.isArray(templateData.stageNames)) {
    stageNames = templateData.stageNames;
  }

  let defectCategories = [];
  if (Array.isArray(templateData.defectCategories)) {
    defectCategories = templateData.defectCategories.map((cat) => ({
      name: cat?.name,
      color: cat?.color || "#2196F3",
      keywords: Array.isArray(cat?.keywords) ? cat.keywords : [],
    }));
  }

  const template = await prisma.template.create({
    data: {
      id: newId(),
      templateName: normalizedTemplateName,
      name: (displayName || normalizedTemplateName).trim(),
      description: (description || "").trim(),
      isActive: true,
      modifiedBy: userId,
      stageData,
      stageNames,
      defectCategories
    }
  });
  
  invalidateTemplate();
  return template;
}

export async function updateTemplatePayload(templateName, displayName, description, templateData, userId) {
  const normalizedTemplateName = (templateName || "").trim();
  if (!normalizedTemplateName) throw new ApiError(400, "templateName is required");

  const existing = await getTemplateByName(normalizedTemplateName);

  const setObj = { modifiedBy: userId };
  if (displayName && displayName.trim()) setObj.name = displayName.trim();
  if (description !== undefined) setObj.description = (description || "").trim();

  if (templateData.stageNames && typeof templateData.stageNames === "object" && !Array.isArray(templateData.stageNames)) {
    setObj.stageNames = templateData.stageNames;
  }

  if (Array.isArray(templateData.defectCategories)) {
    setObj.defectCategories = templateData.defectCategories.map((cat) => ({
      name: cat?.name,
      color: cat?.color || "#2196F3",
      keywords: Array.isArray(cat?.keywords) ? cat.keywords : [],
    }));
  }

  const payloadStageKeys = Object.keys(templateData || {}).filter(key => /^stage\d{1,2}$/.test(key));
  let stageData = parseJsonField(existing.stageData);
  
  const existingStageKeys = Object.keys(stageData);

  // Update provided stages
  for (const key of payloadStageKeys) {
    const value = templateData[key];
    if (Array.isArray(value)) {
      stageData[key] = value;
    }
  }

  // Remove missing stages
  for (const key of existingStageKeys) {
    if (!payloadStageKeys.includes(key)) {
      delete stageData[key];
    }
  }

  setObj.stageData = stageData;

  const updatedTemplate = await prisma.template.update({
    where: { id: existing.id },
    data: setObj
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function getAllTemplateNames(isActive = true) {
  return getOrSet(
    keys.template(`allNames:${isActive}`),
    async () => {
      const query = isActive ? { isActive: true } : {};
      const templates = await prisma.template.findMany({
        where: query,
        select: {
          templateName: true,
          name: true,
          description: true,
          isActive: true,
          createdAt: true,
        },
        orderBy: { createdAt: "desc" },
      });

      return templates;
    },
    TTL.TEMPLATES,
  );
}

export async function getTemplate(templateName, stage) {
  return getOrSet(
    keys.template(`${templateName}:${stage || "all"}`),
    async () => {
      const template = await getTemplateByName(templateName);

      const wasModified = await ensureTemplateConsistency(template);
      if (wasModified) {
        await prisma.template.update({
          where: { id: template.id },
          data: { stageData: template.stageData }
        });
      }

      const stageData = parseJsonField(template.stageData);
      
      if (stage) {
        validateStage(stage);
        return {
          _id: template.id,
          templateName: template.templateName,
          name: template.name,
          description: template.description,
          [stage]: stageData[stage] || [],
          modifiedBy: template.modifiedBy,
          createdAt: template.createdAt,
          updatedAt: template.updatedAt,
        };
      }

      const stageNames = parseJsonField(template.stageNames);
      const defectCategories = parseJsonArray(template.defectCategories);

      return {
        _id: template.id,
        templateName: template.templateName,
        name: template.name,
        description: template.description,
        ...stageData,
        stageNames,
        defectCategories,
        modifiedBy: template.modifiedBy,
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
      };
    },
    TTL.TEMPLATES,
  );
}

export async function updateTemplateMetadata(templateName, updates, userId) {
  const template = await getTemplateByName(templateName);
  
  const updateData = { modifiedBy: userId };
  if (updates.name) updateData.name = updates.name;
  if (updates.description !== undefined) updateData.description = updates.description;
  if (updates.isActive !== undefined) updateData.isActive = updates.isActive;
  
  if (updates.stageNames && typeof updates.stageNames === "object" && !Array.isArray(updates.stageNames)) {
    const currentStageNames = parseJsonField(template.stageNames);
    updateData.stageNames = {
      ...currentStageNames,
      ...updates.stageNames,
    };
  }

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: updateData
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function deleteTemplate(templateName) {
  const template = await getTemplateByName(templateName);
  await prisma.template.delete({ where: { id: template.id } });
  invalidateTemplate();
  return { deletedCount: 1, templateName };
}

export async function duplicateTemplate(sourceTemplateName, newTemplateName, userId) {
  const sourceTemplate = await getTemplateByName(sourceTemplateName);

  const existing = await prisma.template.findFirst({ where: { templateName: newTemplateName } });
  if (existing) {
    throw new ApiError(409, `Template with name "${newTemplateName}" already exists`);
  }

  const newTemplate = await prisma.template.create({
    data: {
      id: newId(),
      templateName: newTemplateName,
      name: `${sourceTemplate.name || sourceTemplateName} (Copy)`,
      description: sourceTemplate.description,
      isActive: sourceTemplate.isActive,
      stageData: parseJsonField(sourceTemplate.stageData),
      stageNames: parseJsonField(sourceTemplate.stageNames),
      defectCategories: parseJsonArray(sourceTemplate.defectCategories),
      modifiedBy: userId,
    }
  });

  invalidateTemplate();
  return newTemplate;
}

// ── Checklist (group) management ──

export async function addChecklistToTemplate(templateName, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);

  if (!Array.isArray(stageData[stage])) stageData[stage] = [];
  stageData[stage].push({
    _id: newId(),
    text: text.trim(),
    checkpoints: [],
    sections: [],
  });

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function updateChecklistInTemplate(templateName, checklistId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  
  checklist.text = text.trim();
  
  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function deleteChecklistFromTemplate(templateName, checklistId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  
  if (Array.isArray(stageData[stage])) {
    stageData[stage] = stageData[stage].filter(item => item._id !== checklistId);
  }

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

// ── Checkpoint (question) management on checklists ──

export async function addCheckpointToTemplate(templateName, checklistId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  const cpData = { _id: newId(), text: text.trim() };
  if (categoryId) cpData.categoryId = categoryId;
  checklist.checkpoints.push(cpData);

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function updateCheckpointInTemplate(templateName, checkpointId, stage, checklistId, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  
  const checkpoint = checklist.checkpoints.find(item => item._id === checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function deleteCheckpointFromTemplate(templateName, checkpointId, stage, checklistId, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  const initialLength = checklist.checkpoints.length;
  checklist.checkpoints = checklist.checkpoints.filter(item => item._id !== checkpointId);

  if (checklist.checkpoints.length === initialLength) {
    throw new ApiError(404, "Checkpoint not found");
  }

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

// ── Section management ──

export async function addSectionToChecklist(templateName, checklistId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  if (!checklist.sections) checklist.sections = [];
  checklist.sections.push({
    _id: newId(),
    text: text.trim(),
    checkpoints: [],
  });

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function updateSectionInChecklist(templateName, checklistId, sectionId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);
  
  section.text = text.trim();

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function deleteSectionFromChecklist(templateName, checklistId, sectionId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  const initialLength = (checklist.sections || []).length;
  checklist.sections = (checklist.sections || []).filter(item => item._id !== sectionId);

  if ((checklist.sections || []).length === initialLength) {
    throw new ApiError(404, "Section not found in this checklist group");
  }

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

// ── Checkpoint management on sections ──

export async function addCheckpointToSection(templateName, checklistId, sectionId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const cpData = { _id: newId(), text: text.trim() };
  if (categoryId) cpData.categoryId = categoryId;
  section.checkpoints.push(cpData);

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function updateCheckpointInSection(templateName, checklistId, sectionId, checkpointId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const checkpoint = section.checkpoints.find(item => item._id === checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found in this section");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function deleteCheckpointFromSection(templateName, checklistId, sectionId, checkpointId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const initialLength = section.checkpoints.length;
  section.checkpoints = section.checkpoints.filter(item => item._id !== checkpointId);

  if (section.checkpoints.length === initialLength) {
    throw new ApiError(404, "Checkpoint not found in this section");
  }

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

// ── Stage management ──

export async function addStageToTemplate(templateName, stage, stageName, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const stageNames = parseJsonField(template.stageNames);

  if (stageData[stage] !== undefined) {
    const existingStages = Object.keys(stageData).filter(key => /^stage\d{1,2}$/.test(key));
    throw new ApiError(400, `${stage} already exists. Available stages: ${existingStages.join(", ")}`);
  }

  stageData[stage] = [];
  if (stageName && stageName.trim()) {
    stageNames[stage] = stageName.trim();
  }

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, stageNames, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function deleteStageFromTemplate(templateName, stage, userId) {
  validateStage(stage);
  const template = await getTemplateByName(templateName);
  const stageData = parseJsonField(template.stageData);
  const stageNames = parseJsonField(template.stageNames);

  if (stageData[stage] === undefined) {
    const availableStages = Object.keys(stageData).filter(key => /^stage\d{1,2}$/.test(key));
    throw new ApiError(404, `Stage ${stage} not found. Available stages: ${availableStages.join(", ")}`);
  }

  delete stageData[stage];
  if (stageNames[stage]) {
    delete stageNames[stage];
  }

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, stageNames, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function renameStageInTemplate(templateName, stage, stageName, userId) {
  validateStage(stage);
  if (!stageName || !stageName.trim()) throw new ApiError(400, "stageName is required");

  const template = await getTemplateByName(templateName);
  const stageNames = parseJsonField(template.stageNames);

  if (parseJsonField(template.stageData)[stage] === undefined) {
    throw new ApiError(404, `Stage ${stage} not found`);
  }

  stageNames[stage] = stageName.trim();

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { stageNames, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

export async function getAllStages(templateName) {
  return getOrSet(
    keys.template(`${templateName}:allStages`),
    async () => {
      const template = await getTemplateByName(templateName);
      const stageData = parseJsonField(template.stageData);
      const stageNames = parseJsonField(template.stageNames);

      const stageKeys = Object.keys(stageData)
        .filter(key => /^stage\d{1,2}$/.test(key))
        .sort((a, b) => parseInt(a.replace("stage", "")) - parseInt(b.replace("stage", "")));

      const stages = {};
      for (const key of stageKeys) {
        stages[key] = stageNames[key] || `Phase ${parseInt(key.replace("stage", ""))}`;
      }
      return stages;
    },
    TTL.TEMPLATES,
  );
}

// ── Defect categories ──

export async function updateDefectCategories(templateName, defectCategories, userId) {
  const template = await getTemplateByName(templateName);
  
  const mappedCategories = defectCategories.map((cat) => ({
    name: cat.name,
    color: cat.color || "#2196F3",
    keywords: cat.keywords || [],
  }));

  const updated = await prisma.template.update({
    where: { id: template.id },
    data: { defectCategories: mappedCategories, modifiedBy: userId }
  });

  invalidateTemplate();
  return updated;
}

// ── Seed ──

export async function seedSampleTemplates(userId) {
  const existing = await prisma.template.count();
  if (existing > 0) {
    return { message: "Templates already exist", count: existing };
  }

  const fealTemplate = await prisma.template.create({
    data: {
      id: newId(),
      templateName: "FEA_Checklist",
      name: "FEA Checklist",
      description: "Finite Element Analysis quality review template",
      stageData: {
        stage1: [
          {
            _id: newId(),
            text: "Model Setup",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Geometry imported correctly" },
              { _id: newId(), text: "Material properties defined" },
              { _id: newId(), text: "Boundary conditions applied" }
            ],
          },
          {
            _id: newId(),
            text: "Meshing",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Mesh density appropriate" },
              { _id: newId(), text: "Element quality verified" },
              { _id: newId(), text: "Refinement zones checked" }
            ],
          }
        ],
        stage2: [
          {
            _id: newId(),
            text: "Analysis Execution",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Solver parameters verified" },
              { _id: newId(), text: "Convergence criteria set" },
              { _id: newId(), text: "Run time reasonable" }
            ],
          }
        ]
      },
      stageNames: {},
      defectCategories: [],
      modifiedBy: userId
    }
  });

  const cfmTemplate = await prisma.template.create({
    data: {
      id: newId(),
      templateName: "CFM_Checklist",
      name: "CFM Checklist",
      description: "Computational Fluid Mechanics review template",
      stageData: {
        stage1: [
          {
            _id: newId(),
            text: "Domain Setup",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Domain geometry defined" },
              { _id: newId(), text: "Inlet/outlet conditions set" },
              { _id: newId(), text: "Wall properties applied" }
            ],
          }
        ],
        stage2: [
          {
            _id: newId(),
            text: "Solution",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Residuals converged" },
              { _id: newId(), text: "Mass balance verified" },
              { _id: newId(), text: "Results physically reasonable" }
            ],
          }
        ]
      },
      stageNames: {},
      defectCategories: [],
      modifiedBy: userId
    }
  });

  invalidateTemplate();
  return { created: 2, templates: [fealTemplate, cfmTemplate] };
}
