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

async function getTemplateSingleton() {
  const template = await prisma.template.findFirst({
    orderBy: { createdAt: "asc" }
  });
  if (!template) throw new ApiError(404, "Template not found");
  return template;
}

function validateStage(stage) {
  if (!isValidStage(stage)) throw new ApiError(400, "Invalid stage format. Must be stage1-99");
}

function findChecklist(stageData, stage, checklistId) {
  if (!Array.isArray(stageData[stage])) {
    throw new ApiError(404, `Stage ${stage} not found or has no checklists`);
  }
  const checklist = stageData[stage].find(
    (item) => item._id === checklistId
  );
  if (!checklist) throw new ApiError(404, "Checklist not found in specified stage");
  return checklist;
}

function findSection(checklist, sectionId) {
  const section = checklist.sections?.find((item) => item._id === sectionId);
  if (!section) throw new ApiError(404, "Section not found in this checklist");
  return section;
}

// ── Template CRUD ──

export async function createOrUpdateTemplate(name, userId) {
  let template = await prisma.template.findFirst({
    orderBy: { createdAt: "asc" }
  });

  if (template) {
    template = await prisma.template.update({
      where: { id: template.id },
      data: {
        name: name || template.name,
        modifiedBy: userId
      }
    });
    invalidateTemplate();
    return { template, created: false };
  }

  template = await prisma.template.create({
    data: {
      id: newId(),
      name: name || "Default Quality Review Template",
      templateName: "default_template",
      modifiedBy: userId,
      stageData: {},
      stageNames: {},
      defectCategories: []
    }
  });

  invalidateTemplate();
  return { template, created: true };
}

export async function getTemplate(stage) {
  return getOrSet(
    keys.template(stage || "all"),
    async () => {
      const template = await getTemplateSingleton();

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
          name: template.name,
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
        name: template.name,
        templateName: template.templateName,
        description: template.description,
        ...stageData,
        stageNames,
        defectCategories,
        modifiedBy: template.modifiedBy,
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
      };
    },
    TTL.TEMPLATES
  );
}

export async function resetTemplate() {
  const result = await prisma.template.deleteMany({});
  invalidateTemplate();
  return { deletedCount: result.count };
}

// ── Checklist (group) management ──

export async function addChecklistToTemplate(stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);

  if (!Array.isArray(stageData[stage])) stageData[stage] = [];
  stageData[stage].push({
    _id: newId(),
    text: text.trim(),
    checkpoints: [],
    sections: [],
  });

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function updateChecklistInTemplate(checklistId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  
  checklist.text = text.trim();

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function deleteChecklistFromTemplate(checklistId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  
  if (Array.isArray(stageData[stage])) {
    stageData[stage] = stageData[stage].filter(c => c._id !== checklistId);
  }

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

// ── Checkpoint (question) management on checklists ──

export async function addCheckpointToTemplate(checklistId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  const cpData = { _id: newId(), text: text.trim() };
  if (categoryId) cpData.categoryId = categoryId;
  checklist.checkpoints.push(cpData);

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function updateCheckpointInTemplate(checkpointId, stage, checklistId, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const checkpoint = checklist.checkpoints.find(item => item._id === checkpointId);
  
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function deleteCheckpointFromTemplate(checkpointId, stage, checklistId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  const initialLength = checklist.checkpoints.length;
  checklist.checkpoints = checklist.checkpoints.filter(item => item._id !== checkpointId);

  if (checklist.checkpoints.length === initialLength) {
    throw new ApiError(404, "Checkpoint not found");
  }

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

// ── Section management ──

export async function addSectionToChecklist(checklistId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  if (!checklist.sections) checklist.sections = [];
  checklist.sections.push({
    _id: newId(),
    text: text.trim(),
    checkpoints: [],
  });

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function updateSectionInChecklist(checklistId, sectionId, stage, text, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);
  
  section.text = text.trim();

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function deleteSectionFromChecklist(checklistId, sectionId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);

  const initialLength = (checklist.sections || []).length;
  checklist.sections = (checklist.sections || []).filter(item => item._id !== sectionId);

  if (checklist.sections.length === initialLength) {
    throw new ApiError(404, "Section not found in this checklist group");
  }

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

// ── Checkpoint management on sections ──

export async function addCheckpointToSection(checklistId, sectionId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const cpData = { _id: newId(), text: text.trim() };
  if (categoryId) cpData.categoryId = categoryId;
  section.checkpoints.push(cpData);

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function updateCheckpointInSection(checklistId, sectionId, checkpointId, stage, text, categoryId, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const checkpoint = section.checkpoints.find(item => item._id === checkpointId);
  if (!checkpoint) throw new ApiError(404, "Checkpoint not found in this section");

  checkpoint.text = text.trim();
  if (categoryId !== undefined) checkpoint.categoryId = categoryId;

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function deleteCheckpointFromSection(checklistId, sectionId, checkpointId, stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const checklist = findChecklist(stageData, stage, checklistId);
  const section = findSection(checklist, sectionId);

  const initialLength = section.checkpoints.length;
  section.checkpoints = section.checkpoints.filter(item => item._id !== checkpointId);

  if (section.checkpoints.length === initialLength) {
    throw new ApiError(404, "Checkpoint not found in this section");
  }

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

// ── Stage management ──

export async function addStageToTemplate(stage, stageName, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
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

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, stageNames, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function deleteStageFromTemplate(stage, userId) {
  validateStage(stage);
  const template = await getTemplateSingleton();
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

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageData, stageNames, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function renameStageInTemplate(stage, stageName, userId) {
  validateStage(stage);
  if (!stageName || !stageName.trim()) throw new ApiError(400, "stageName is required");

  const template = await getTemplateSingleton();
  const stageData = parseJsonField(template.stageData);
  const stageNames = parseJsonField(template.stageNames);

  if (stageData[stage] === undefined) {
    throw new ApiError(404, `Stage ${stage} not found`);
  }

  stageNames[stage] = stageName.trim();

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { stageNames, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

export async function getAllStages() {
  return getOrSet(
    keys.template("allStages"),
    async () => {
      const template = await getTemplateSingleton();
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
    TTL.TEMPLATES
  );
}

// ── Defect categories ──

export async function updateDefectCategories(defectCategories, userId) {
  const template = await getTemplateSingleton();
  
  const mappedCategories = defectCategories.map((cat) => ({
    name: cat.name,
    color: cat.color || "#2196F3",
    keywords: Array.isArray(cat.keywords) ? cat.keywords : [],
  }));

  const updatedTemplate = await prisma.template.update({
    where: { id: template.id },
    data: { defectCategories: mappedCategories, modifiedBy: userId }
  });

  invalidateTemplate();
  return updatedTemplate;
}

// ── Seed ──

export async function seedTemplate(userId) {
  let template = await prisma.template.findFirst({ orderBy: { createdAt: "asc" } });
  if (template) return { template, alreadyExists: true };

  template = await prisma.template.create({
    data: {
      id: newId(),
      name: "Quality Review Process Template",
      templateName: "default_template",
      stageData: {
        stage1: [
          {
            _id: newId(),
            text: "Planning & Requirements",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Project scope documented and approved" },
              { _id: newId(), text: "Requirements clearly defined" },
              { _id: newId(), text: "Timeline and budget approved" }
            ],
          },
          {
            _id: newId(),
            text: "Team Setup",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Team members assigned" },
              { _id: newId(), text: "Roles and responsibilities defined" },
              { _id: newId(), text: "Communication channels established" }
            ],
          }
        ],
        stage2: [
          {
            _id: newId(),
            text: "Development & Testing",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Code review completed" },
              { _id: newId(), text: "Unit tests written and passed" },
              { _id: newId(), text: "Integration testing done" }
            ],
          },
          {
            _id: newId(),
            text: "Quality Assurance",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "All bugs documented and fixed" },
              { _id: newId(), text: "Performance testing completed" },
              { _id: newId(), text: "Security review done" }
            ],
          }
        ],
        stage3: [
          {
            _id: newId(),
            text: "Deployment Preparation",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Deployment plan documented" },
              { _id: newId(), text: "Rollback plan prepared" },
              { _id: newId(), text: "Production environment ready" }
            ],
          },
          {
            _id: newId(),
            text: "Post-Deployment",
            sections: [],
            checkpoints: [
              { _id: newId(), text: "Deployment successful" },
              { _id: newId(), text: "Monitoring and logging active" },
              { _id: newId(), text: "User documentation complete" }
            ],
          }
        ]
      },
      stageNames: {
        stage1: "Phase 1 Assessment",
        stage2: "Phase 2 Assessment",
        stage3: "Phase 3 Assessment"
      },
      defectCategories: [],
      modifiedBy: userId
    }
  });

  invalidateTemplate();
  return { template, alreadyExists: false };
}
