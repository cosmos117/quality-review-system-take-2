import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { newId } from "../utils/newId.js";

// In-memory cache to avoid hitting the DB on every checklist open
// TTL: 5 minutes (300000ms)
let _categoriesCache = null;
let _cacheExpiry = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

function invalidateCache() {
  _categoriesCache = null;
  _cacheExpiry = 0;
}

export { invalidateCache };

/**
 * Get all global defect categories
 */
export async function getGlobalDefectCategories() {
  // Return cached value if still fresh
  if (_categoriesCache && Date.now() < _cacheExpiry) {
    return _categoriesCache.categories;
  }

  let categories = await prisma.globalDefectCategory.findMany({
    orderBy: { name: "asc" }
  });

  // If empty, seed from existing templates (only happens once per server boot)
  if (categories.length === 0) {
    await seedGlobalDefectCategories();
    categories = await prisma.globalDefectCategory.findMany({
      orderBy: { name: "asc" }
    });
  }

  return categories;
}

/**
 * Get global defect category settings (groups)
 */
export async function getGlobalDefectSettings() {
  // Return cached value if still fresh
  if (_categoriesCache && Date.now() < _cacheExpiry) {
    return _categoriesCache.settings;
  }

  let settings = await prisma.globalDefectCategorySettings.findFirst();

  if (!settings) {
    settings = await prisma.globalDefectCategorySettings.create({
      data: {
        id: newId(),
        defectCategoryGroups: ["General", "Modelling Strategy", "Results & Output", "Meshing"]
      }
    });
  }

  return settings;
}

/**
 * Get both categories and settings in a single call (used by controller to avoid 2 round trips)
 */
export async function getGlobalDefectData() {
  // Return from cache if fresh
  if (_categoriesCache && Date.now() < _cacheExpiry) {
    return _categoriesCache;
  }

  // Fetch both in parallel to halve latency
  let [categories, settings] = await Promise.all([
    prisma.globalDefectCategory.findMany({ orderBy: { name: "asc" } }),
    prisma.globalDefectCategorySettings.findFirst()
  ]);

  // Seed if empty (first ever call)
  if (categories.length === 0) {
    await seedGlobalDefectCategories();
    [categories, settings] = await Promise.all([
      prisma.globalDefectCategory.findMany({ orderBy: { name: "asc" } }),
      prisma.globalDefectCategorySettings.findFirst()
    ]);
  }

  if (!settings) {
    settings = await prisma.globalDefectCategorySettings.create({
      data: {
        id: newId(),
        defectCategoryGroups: ["General", "Modelling Strategy", "Results & Output", "Meshing"]
      }
    });
  }

  // Cache the result
  _categoriesCache = { categories, settings };
  _cacheExpiry = Date.now() + CACHE_TTL_MS;

  return _categoriesCache;
}

/**
 * Update global defect categories and groups
 */
export async function updateGlobalDefectCategories(categories, groups) {
  // Use a transaction to update both if needed
  return await prisma.$transaction(async (tx) => {
    // 1. Update/Create categories
    // We'll replace the existing ones for simplicity, matching the current template logic
    await tx.globalDefectCategory.deleteMany({});
    
    const hex24 = /^[0-9a-fA-F]{24}$/;
    const mapped = categories.map(cat => {
      // Use existing ID if it's already a valid 24-char hex (Prisma format)
      let finalId = (cat.id || cat._id || '').toString();
      if (!hex24.test(finalId)) {
        finalId = newId();
      }
      
      return {
        id: finalId,
        name: cat.name,
        group: cat.group || "General",
        keywords: Array.isArray(cat.keywords) ? cat.keywords : []
      };
    });

    try {
      await tx.globalDefectCategory.createMany({
        data: mapped,
        skipDuplicates: true // Safety fallback
      });
    } catch (error) {
      console.error("[DefectCategoryService] Error seeding categories:", error);
      throw error;
    }

    // 2. Update settings (groups)
    let settings = await tx.globalDefectCategorySettings.findFirst();
    if (!settings) {
      settings = await tx.globalDefectCategorySettings.create({
        data: {
          id: newId(),
          defectCategoryGroups: groups || []
        }
      });
    } else {
      settings = await tx.globalDefectCategorySettings.update({
        where: { id: settings.id },
        data: {
          defectCategoryGroups: groups || []
        }
      });
    }

    const result = { categories: mapped, settings };
    // Always invalidate cache after an update
    invalidateCache();
    return result;
  });
}

/**
 * Seed global defect categories from defaults or existing templates
 */
async function seedGlobalDefectCategories() {
  // Fetch all templates and filter in JS to avoid Prisma JSON validation issues for now
  const allTemplates = await prisma.template.findMany();
  const templates = allTemplates.filter(t => t.defectCategories != null && typeof t.defectCategories === 'object' && Array.isArray(t.defectCategories));

  let sourceCategories = [];
  let sourceGroups = [];

  for (const t of templates) {
    const cats = Array.isArray(t.defectCategories) ? t.defectCategories : [];
    const groups = Array.isArray(t.defectCategoryGroups) ? t.defectCategoryGroups : [];
    
    // Simple merge: add if not already present by name
    for (const cat of cats) {
      if (!sourceCategories.find(c => c.name === cat.name)) {
        sourceCategories.push(cat);
      }
    }
    for (const group of groups) {
      if (!sourceGroups.includes(group)) {
        sourceGroups.push(group);
      }
    }
  }

  if (sourceCategories.length === 0) {
    // Fallback to hardcoded defaults if no templates found
    sourceCategories = getDefaultCategories();
    sourceGroups = ["General", "Modelling Strategy", "Results & Output", "Meshing"];
  }

  await updateGlobalDefectCategories(sourceCategories, sourceGroups);
}

function getDefaultCategories() {
  const names = [
    'Incorrect Modelling Strategy - Geometry',
    'Incorrect Modelling Strategy - Material',
    'Incorrect Modelling Strategy - Loads',
    'Incorrect Modelling Strategy - BC',
    'Incorrect Modelling Strategy - Assumptions',
    'Incorrect Modelling Strategy - Acceptance Criteria',
    'Incorrect geometry units',
    'Incorrect meshing',
    'Defective mesh quality',
    'Incorrect contact definition',
    'Incorrect beam/bolt modeling',
    'RBE/RBE3 are not modeled properly',
    'Incorrect loads and Boundary Condition',
    'Incorrect connectivity',
    'Incorrect degree of element order',
    'Incorrect element quality',
    'Incorrect bolt size',
    'Incorrect elements order',
    'Incorrect elements quality',
    'Incorrect end loads',
    'Too refined mesh at the non critical regions',
    'Support Gap',
    'Support Location',
    'Incorrect Scope',
    'free pages',
    'Incorrect mass modeling',
    'Incorrect material properties',
    'Incorrect global output request',
    'Incorrect loadstep creation',
    'Incorrect output request',
    'Incorrect Interpretation',
    'Incorrect Results location and Values',
    'Incorrect Observation',
    'Incorrect Naming',
    'Missing Results Plot',
    'Incomplete conclusion, suggestions',
    'Template not followed',
    'Checklist not followed',
    'Planning sheet not followed',
    'Folder Structure not followed',
    'Name/revision report incorrect',
    'Typo Textual Error',
  ];
  return names.map((name, i) => {
    let groupName = 'General';
    if (name.startsWith('Incorrect Modelling Strategy')) {
      groupName = 'Modelling Strategy';
    } else if (name.toLowerCase().includes('results') || name.toLowerCase().includes('output')) {
      groupName = 'Results & Output';
    } else if (name.toLowerCase().includes('mesh')) {
      groupName = 'Meshing';
    }

    return {
      id: `cat_global_${i + 1}`,
      name,
      group: groupName,
      keywords: name
        .toLowerCase()
        .replace(/[-/\\]/g, ' ')
        .split(/\s+/)
        .filter((w) => w.length > 1),
    };
  });
}
