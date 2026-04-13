import prisma from "./src/config/prisma.js";
import { newId } from "./src/utils/newId.js";

async function hardReset() {
  console.log("--- Starting Defect Category Hard Reset ---");
  
  // 1. Clear existing categories
  console.log("Cleaning GlobalDefectCategory table...");
  await prisma.globalDefectCategory.deleteMany({});
  
  // 2. Define standard defaults
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

  const mapped = names.map(name => {
    let groupName = 'General';
    if (name.startsWith('Incorrect Modelling Strategy')) {
      groupName = 'Modelling Strategy';
    } else if (name.toLowerCase().includes('results') || name.toLowerCase().includes('output')) {
      groupName = 'Results & Output';
    } else if (name.toLowerCase().includes('mesh')) {
      groupName = 'Meshing';
    }

    return {
      id: newId(), // FRESH 24-CHAR HEX ID
      name,
      group: groupName,
      keywords: name
        .toLowerCase()
        .replace(/[-/\\]/g, ' ')
        .split(/\s+/)
        .filter((w) => w.length > 1),
    };
  });

  console.log(`Seeding ${mapped.length} categories with unique hex IDs...`);
  
  await prisma.globalDefectCategory.createMany({
    data: mapped
  });

  console.log("--- Hard Reset Complete Success! ---");
}

hardReset()
  .catch(e => {
    console.error("Hard Reset Failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
