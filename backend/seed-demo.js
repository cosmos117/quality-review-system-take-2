/**
 * Demo data seeder.
 *
 *   npm run seed:demo        (or: node -r dotenv/config seed-demo.js)
 *
 * Creates:
 *   - Project roles: TeamLeader, Executor, Reviewer (if missing)
 *   - 12 employees  (login: <firstname>@gmail.com / <firstname>1)
 *   - 5 checklist templates (2-3 phases, 3-4 checkpoints per phase)
 *   - 48 projects with team assignments, phases, checklist answers,
 *     review iterations (reverts) and categorised defects so the
 *     analytics dashboard is populated.
 *
 * Re-runnable: each run first removes only the data this script created
 * (templates by name, projects whose project_no starts with "QRP-") and
 * updates the demo users in place, keeping their ids. admin@gmail.com, reviewer@gmail.com, default_template and
 * the global defect categories are never touched.
 *
 * Output is deterministic (seeded RNG), so every run produces the same data.
 */
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcrypt";
import { randomBytes } from "crypto";
import {
  calculateCurrentMismatches,
  calculateIterationDefectRates,
} from "./src/services/defectUtility.service.js";

const prisma = new PrismaClient();

const PROJECT_NO_PREFIX = "QRP-";
const STATUS_DB = { "Not Started": "pending", "In Progress": "in_progress", Completed: "completed" };
const TODAY = new Date("2026-11-19T10:00:00Z");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const newId = () => randomBytes(12).toString("hex");

// mulberry32: small deterministic PRNG
function makeRng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = makeRng(20261119);
const rand = () => rng();
const randInt = (min, max) => min + Math.floor(rand() * (max - min + 1));
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const chance = (p) => rand() < p;
const shuffle = (arr) => {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const sample = (arr, n) => shuffle(arr).slice(0, n);
const weighted = (pairs) => {
  const total = pairs.reduce((s, [, w]) => s + w, 0);
  let r = rand() * total;
  for (const [v, w] of pairs) {
    if ((r -= w) <= 0) return v;
  }
  return pairs[pairs.length - 1][0];
};
const addDays = (d, n) => new Date(d.getTime() + n * 86400000);
const addHours = (d, n) => new Date(d.getTime() + n * 3600000);
const clone = (o) => JSON.parse(JSON.stringify(o));

// ---------------------------------------------------------------------------
// Employees
// ---------------------------------------------------------------------------

const EMPLOYEES = [
  "Aarav Sharma",
  "Priya Patel",
  "Rohan Mehta",
  "Ananya Iyer",
  "Vikram Singh",
  "Sneha Reddy",
  "Karan Malhotra",
  "Neha Joshi",
  "Arjun Nair",
  "Pooja Desai",
  "Rahul Verma",
  "Ishita Kapoor",
];
const firstName = (full) => full.split(" ")[0].toLowerCase();
const emailOf = (full) => `${firstName(full)}@gmail.com`;

// Seniors lead most projects, so "DR by Team Leader" has a meaningful spread.
const TEAM_LEADER_POOL = ["Aarav Sharma", "Priya Patel", "Vikram Singh", "Neha Joshi", "Rahul Verma"];
const REVIEWER_POOL = ["Rohan Mehta", "Ananya Iyer", "Karan Malhotra", "Pooja Desai", "Ishita Kapoor", "Priya Patel"];

// ---------------------------------------------------------------------------
// Templates
// Each checkpoint: text, cats (global defect category names a reviewer would
// pick for it), remarks (reviewer comments when it is flagged as a defect).
// ---------------------------------------------------------------------------

const TEMPLATES = [
  {
    templateName: "CFD Analysis",
    description: "Quality checklist for CFD jobs: kick-off, meshing/case setup, convergence and post processing.",
    phases: [
      {
        checklist: "Kick-off",
        checkpoints: [
          { text: "Is the Statement of Work defined properly and is the background included?", cats: ["Incorrect Scope", "Planning sheet not followed"], remarks: ["Background section missing from SOW; customer objective not captured.", "SOW does not mention the second operating point requested in the job mail."] },
          { text: "Is FAD/NTP/SCFM converted properly to operating conditions?", cats: ["Incorrect loads and Boundary Condition", "Incorrect Modelling Strategy - Loads"], remarks: ["FAD converted at 20 °C instead of the specified 35 °C inlet temperature.", "SCFM to kg/s conversion uses wrong reference density."] },
          { text: "Are porous zone / jump coefficients calculated correctly (no copy-paste errors)?", cats: ["Incorrect Modelling Strategy - Assumptions", "Incorrect material properties"], remarks: ["Inertial resistance copied from previous project; filter media is different.", "Viscous and inertial coefficients swapped in the calculation sheet."] },
          { text: "Is the solid model quality checked and does it carry the correct part number?", cats: ["Name/revision report incorrect", "Incorrect Modelling Strategy - Geometry"], remarks: ["CAD revision B used, job request refers to revision C.", "Part number in model tree does not match the drawing."] },
        ],
      },
      {
        checklist: "Geometry Cleanup, Meshing & Case Setup",
        checkpoints: [
          { text: "Are units checked before and after importing the geometry?", cats: ["Incorrect geometry units"], remarks: ["Geometry imported in inches; domain is 25.4x oversized.", "Unit scaling not verified after import, bounding box inconsistent with drawing."] },
          { text: "Is the mesh quality within acceptability limits (skewness < 0.90)?", cats: ["Defective mesh quality", "Incorrect meshing"], remarks: ["Max skewness 0.96 near the grille interior.", "Poor quality cells at the fan shroud tip clearance."] },
          { text: "Is the first cell height calculated from Reynolds number and the turbulence model?", cats: ["Incorrect meshing", "Too refined mesh at the non critical regions"], remarks: ["y+ target for k-omega SST not respected; first layer too thick.", "Inflation layers missing on the heat exchanger walls."] },
          { text: "Are boundary conditions and named selections assigned to the correct zones?", cats: ["Incorrect loads and Boundary Condition", "Incorrect Naming", "Incorrect Modelling Strategy - BC"], remarks: ["Outlet defined as pressure inlet on the louvre face.", "Named selection 'inlet_2' assigned to the wrong face group."] },
        ],
      },
      {
        checklist: "Convergence & Post Processing",
        checkpoints: [
          { text: "Is mass flux balanced within 0.2%?", cats: ["Incorrect Results location and Values", "Incorrect Interpretation"], remarks: ["Mass imbalance 0.8%; solution not converged.", "Mass flux report taken at iteration 300, monitors still drifting."] },
          { text: "Is heat flux balanced within 1.0%?", cats: ["Incorrect Results location and Values"], remarks: ["Heat imbalance 3.2% due to missing shell conduction zone.", "Energy residual flat but heat balance not reported."] },
          { text: "Is wall y+ within limits for the chosen turbulence model?", cats: ["Incorrect meshing", "Incorrect Observation"], remarks: ["Wall y+ up to 45 on the cooler fins with low-Re model.", "y+ plot not included; cannot confirm wall treatment."] },
          { text: "Are contours compared on a common fringe scale and is the report as per template?", cats: ["Template not followed", "Missing Results Plot", "Incomplete conclusion, suggestions"], remarks: ["Baseline and modified design use different legend ranges.", "Velocity contour at the critical plane missing in the report."] },
        ],
      },
    ],
  },
  {
    templateName: "Pulsation Study (Pulsim)",
    description: "Acoustic pulsation study checklist for reciprocating compressor piping using PULSIM.",
    phases: [
      {
        checklist: "Planning & Input Calculations",
        checkpoints: [
          { text: "Is the job request clear and are all inputs available?", cats: ["Incorrect Scope", "Planning sheet not followed"], remarks: ["Missing information (valve data) not listed in remarks.", "Job request mentions two load steps; only one captured."] },
          { text: "Are input calculations (valve volumes, pipe lengths) done correctly?", cats: ["Incorrect Modelling Strategy - Geometry", "Incorrect Interpretation"], remarks: ["Valve volume calculated with mechanical instead of acoustic length.", "Pipe length from isometric missing the 90° bend allowance."] },
          { text: "Are pressure, temperature, loading conditions and bore/stroke taken from the Wincomp sheet?", cats: ["Incorrect loads and Boundary Condition", "Checklist not followed"], remarks: ["Discharge temperature taken from the data sheet, not the latest Wincomp run.", "Stroke value 120 mm used; Wincomp shows 140 mm."] },
          { text: "Is the delivery date achievable and is the CAE project management sheet filled?", cats: ["Planning sheet not followed"], remarks: ["PM sheet not updated with planned hours.", "Revised delivery date not agreed with the customer in writing."] },
        ],
      },
      {
        checklist: "PULSIM Modelling",
        checkpoints: [
          { text: "Is the gas composition in the software verified against the Wincomp sheet?", cats: ["Incorrect material properties", "Incorrect Modelling Strategy - Material"], remarks: ["H2S fraction missing in gas composition.", "Gas composition mole fractions do not sum to 100%."] },
          { text: "Are pipe inner diameters entered in millimetres?", cats: ["Incorrect geometry units", "Incorrect Modelling Strategy - Geometry"], remarks: ["Outer diameter entered for the 6\" suction line.", "Diameter entered in inches for two pipe elements."] },
          { text: "Is pressure entered in kPa and temperature in °C (Wincomp is in Bara)?", cats: ["Incorrect loads and Boundary Condition", "Incorrect geometry units"], remarks: ["Suction pressure entered as 4.5 instead of 450 kPa.", "Bara value used directly without conversion."] },
          { text: "Are friction factors (Kw) set according to flow direction (0.5 / 1.0)?", cats: ["Incorrect Modelling Strategy - BC", "Incorrect Modelling Strategy - Assumptions"], remarks: ["Kw = 0.5 used for an expansion; should be 1.0.", "Default Kw left on all reducers."] },
        ],
      },
      {
        checklist: "Post Processing & Reporting",
        checkpoints: [
          { text: "Are pulsation levels at all pressure points within the limit (solution suggested if not)?", cats: ["Incorrect Results location and Values", "Incomplete conclusion, suggestions"], remarks: ["Pressure point P7 exceeds limit; no mitigation proposed.", "Pulsation evaluated only at nominal speed."] },
          { text: "Is the orifice pressure drop within the limit and the orifice location feasible?", cats: ["Incorrect Interpretation", "Support Location"], remarks: ["Orifice placed inside the flange of the damper nozzle; not feasible.", "Pressure drop across orifice 1.8%, limit is 1%."] },
          { text: "Is the shaking force below 5 kNpp?", cats: ["Incorrect Results location and Values", "Incorrect Observation"], remarks: ["Shaking force 6.2 kNpp on the discharge damper not reported.", "Shaking forces reported only for the first harmonic."] },
          { text: "Is the output summary sheet filled and is the folder structure / read-me generated?", cats: ["Folder Structure not followed", "Template not followed"], remarks: ["Read-me file missing in the job folder.", "Output summary sheet missing harmonic levels."] },
        ],
      },
    ],
  },
  {
    templateName: "FEA Structural Analysis",
    description: "Linear/non-linear structural FEA checklist covering pre-processing, meshing/BCs and results.",
    phases: [
      {
        checklist: "Pre-processing & Geometry",
        checkpoints: [
          { text: "Is the CAD imported with correct units and the correct part revision?", cats: ["Incorrect geometry units", "Name/revision report incorrect"], remarks: ["Model in mm, material density in kg/m³: mass off by 1e9.", "Old revision of the base frame used."] },
          { text: "Is the geometry defeatured without removing load paths?", cats: ["Incorrect Modelling Strategy - Geometry"], remarks: ["Stiffener plate removed during cleanup; it carries the lifting load.", "Weld fillets removed at the hotspot location."] },
          { text: "Are material properties defined per specification at operating temperature?", cats: ["Incorrect material properties", "Incorrect Modelling Strategy - Material"], remarks: ["Yield strength at room temperature used; operating at 180 °C.", "S355 properties assigned to the S235 bracket."] },
        ],
      },
      {
        checklist: "Meshing & Boundary Conditions",
        checkpoints: [
          { text: "Is the mesh quality (aspect ratio, jacobian, warpage) within limits?", cats: ["Incorrect element quality", "Defective mesh quality", "Incorrect elements quality"], remarks: ["Warpage > 15° on 40 shell elements around the cut-out.", "Jacobian < 0.6 on tet elements at the fillet."] },
          { text: "Are element type and order appropriate (2nd order tets, no linear tets in bending)?", cats: ["Incorrect degree of element order", "Incorrect elements order"], remarks: ["Linear tetra used in the bending-dominated bracket.", "Mixed element order at the shell-solid interface."] },
          { text: "Are contacts, bolts and pretension modelled correctly?", cats: ["Incorrect contact definition", "Incorrect beam/bolt modeling", "Incorrect bolt size", "RBE/RBE3 are not modeled properly"], remarks: ["Bonded contact used at the bolted flange; should be frictional.", "M16 bolts modelled as M12; pretension too low.", "RBE2 spider over-stiffens the motor foot."] },
          { text: "Are loads and boundary conditions applied as per the load case sheet?", cats: ["Incorrect loads and Boundary Condition", "Incorrect loadstep creation", "Incorrect end loads"], remarks: ["Seismic load applied only in X direction.", "Load step 3 missing the thermal load.", "Fixed support over-constrains thermal expansion."] },
        ],
      },
      {
        checklist: "Results & Reporting",
        checkpoints: [
          { text: "Do reaction forces balance the applied loads?", cats: ["Incorrect Results location and Values", "Incorrect mass modeling"], remarks: ["Reaction sum 12% lower than applied gravity load.", "Point mass of motor not connected; missing in reaction."] },
          { text: "Are stresses evaluated against the acceptance criteria at critical locations?", cats: ["Incorrect Modelling Strategy - Acceptance Criteria", "Incorrect Interpretation"], remarks: ["Peak singular stress compared with yield; should use linearised stress.", "Weld stresses not evaluated per EN 1993-1-8."] },
          { text: "Is the report complete with conclusions and recommendations?", cats: ["Incomplete conclusion, suggestions", "Typo Textual Error", "Missing Results Plot"], remarks: ["Conclusion does not state whether the design is acceptable.", "Displacement plot missing for load case 2."] },
        ],
      },
    ],
  },
  {
    templateName: "Thermal Analysis",
    description: "Steady-state / transient thermal analysis checklist for enclosures, motors and heat exchangers.",
    phases: [
      {
        checklist: "Model Setup",
        checkpoints: [
          { text: "Are heat loads / sources applied as per the input data?", cats: ["Incorrect Modelling Strategy - Loads", "Incorrect loads and Boundary Condition"], remarks: ["VFD losses taken at 50% load instead of 100%.", "Copper losses applied as surface flux instead of volume source."] },
          { text: "Are convection coefficients and ambient conditions correct?", cats: ["Incorrect Modelling Strategy - BC", "Incorrect Modelling Strategy - Assumptions"], remarks: ["Ambient taken as 25 °C; customer specification is 45 °C.", "Forced convection HTC used on a naturally cooled surface."] },
          { text: "Are temperature-dependent material properties used?", cats: ["Incorrect material properties"], remarks: ["Constant conductivity used for the insulation material.", "Specific heat missing for the transient run."] },
          { text: "Are contact conductance and radiation modelled where relevant?", cats: ["Incorrect contact definition", "Incorrect Modelling Strategy - Assumptions"], remarks: ["Perfect contact assumed across the thermal pad.", "Radiation neglected for surfaces above 150 °C."] },
        ],
      },
      {
        checklist: "Solution & Reporting",
        checkpoints: [
          { text: "Is the energy balance within 1%?", cats: ["Incorrect Results location and Values"], remarks: ["Energy imbalance 4% in the steady run.", "Energy balance not reported."] },
          { text: "Is the time step / end time adequate for the transient analysis?", cats: ["Incorrect loadstep creation", "Incorrect output request"], remarks: ["End time 600 s; component not yet at steady state.", "Output requested only at the final time step."] },
          { text: "Are maximum temperatures compared with allowable limits?", cats: ["Incorrect Modelling Strategy - Acceptance Criteria", "Incorrect Interpretation"], remarks: ["IGBT junction temperature limit not checked.", "Class F insulation limit used; motor is Class B."] },
          { text: "Are temperature contours presented on a common scale in the report?", cats: ["Missing Results Plot", "Template not followed"], remarks: ["Contours of baseline and option 2 use different scales.", "Section plot through the winding missing."] },
        ],
      },
    ],
  },
  {
    templateName: "Piping Stress Analysis",
    description: "Piping flexibility and code compliance checklist (ASME B31.3).",
    phases: [
      {
        checklist: "Input Verification & Modelling",
        checkpoints: [
          { text: "Are isometrics of the latest revision used?", cats: ["Name/revision report incorrect", "Checklist not followed"], remarks: ["Isometric rev 2 used; rev 3 adds a new branch.", "Line number in model does not match the isometric."] },
          { text: "Are design pressure, temperature and material taken from the line list?", cats: ["Incorrect material properties", "Incorrect loads and Boundary Condition"], remarks: ["Design temperature 120 °C; line list says 165 °C.", "A106 Gr B used; line is SS316L."] },
          { text: "Are supports and restraints modelled as per the support layout?", cats: ["Support Location", "Support Gap", "Incorrect connectivity"], remarks: ["Guide at node 140 modelled as anchor.", "Support gap of 3 mm not modelled on the line stop.", "Branch not connected to the header at node 230."] },
          { text: "Are SIFs applied correctly for tees and bends?", cats: ["Incorrect Modelling Strategy - Assumptions"], remarks: ["Reinforced tee modelled as unreinforced fabricated tee.", "Bend radius set to 1D instead of 1.5D."] },
        ],
      },
      {
        checklist: "Load Cases & Code Compliance",
        checkpoints: [
          { text: "Are load cases defined per code (sustained, expansion, occasional)?", cats: ["Incorrect loadstep creation", "Incorrect Modelling Strategy - Loads"], remarks: ["Wind load case missing.", "Expansion case computed as algebraic difference without operating case."] },
          { text: "Are stresses within the B31.3 allowable?", cats: ["Incorrect Modelling Strategy - Acceptance Criteria", "Incorrect Results location and Values"], remarks: ["Expansion stress ratio 108% at the elbow not reported.", "Allowable taken at ambient instead of design temperature."] },
          { text: "Are nozzle loads checked against equipment allowables?", cats: ["Incorrect end loads", "Incorrect Interpretation"], remarks: ["Pump nozzle checked against API 610 1x instead of 2x table.", "Moment Mz at compressor nozzle exceeds vendor allowable."] },
          { text: "Are support loads issued and displacements checked?", cats: ["Incomplete conclusion, suggestions", "Missing Results Plot"], remarks: ["Support load summary not issued to the civil team.", "Thermal displacement at the loop exceeds 50 mm, not commented."] },
        ],
      },
    ],
  },
];

// ---------------------------------------------------------------------------
// Projects (48). Statuses: 7 Not Started / 22 In Progress / 19 Completed.
// ---------------------------------------------------------------------------

const PROJECTS = [
  ["CFD Analysis", "Compressor Package Cooler Airflow Study"],
  ["CFD Analysis", "Control Panel Enclosure Ventilation CFD"],
  ["CFD Analysis", "Intake Filter House Flow Uniformity"],
  ["CFD Analysis", "Aftercooler Fan Shroud Optimization"],
  ["CFD Analysis", "Oil Separator Vessel Internal Flow"],
  ["CFD Analysis", "Silencer Pressure Drop Evaluation"],
  ["CFD Analysis", "Dryer Inlet Manifold Flow Distribution"],
  ["CFD Analysis", "Canopy Recirculation Study GA90"],
  ["Pulsation Study (Pulsim)", "Two-Stage Recip Suction Pulsation Study"],
  ["Pulsation Study (Pulsim)", "HP Line Discharge Damper Sizing"],
  ["Pulsation Study (Pulsim)", "Booster Compressor Acoustic Analysis"],
  ["Pulsation Study (Pulsim)", "CNG Station Pulsation Study"],
  ["Pulsation Study (Pulsim)", "Hydrogen Recip Compressor Pulsation Check"],
  ["Pulsation Study (Pulsim)", "Process Gas Compressor Orifice Optimization"],
  ["Pulsation Study (Pulsim)", "Fuel Gas Line Pulsation Review"],
  ["Pulsation Study (Pulsim)", "LNG BOG Compressor Acoustic Study"],
  ["FEA Structural Analysis", "Skid Base Frame Lifting Analysis"],
  ["FEA Structural Analysis", "Pressure Vessel Nozzle Load Check"],
  ["FEA Structural Analysis", "Motor Mounting Bracket Strength Analysis"],
  ["FEA Structural Analysis", "Cooler Support Structure Seismic Check"],
  ["FEA Structural Analysis", "Coupling Guard Static Analysis"],
  ["FEA Structural Analysis", "Lifting Lug Design Verification"],
  ["FEA Structural Analysis", "Compressor Frame Bolted Joint Analysis"],
  ["FEA Structural Analysis", "Rooftop Unit Support Frame Analysis"],
  ["Thermal Analysis", "Motor Winding Thermal Assessment"],
  ["Thermal Analysis", "VFD Cabinet Heat Dissipation Study"],
  ["Thermal Analysis", "Oil Cooler Thermal Performance Check"],
  ["Thermal Analysis", "Heat Exchanger Tube Sheet Thermal Gradient"],
  ["Thermal Analysis", "Battery Enclosure Thermal Management"],
  ["Thermal Analysis", "Electronics Housing Thermal Analysis"],
  ["Thermal Analysis", "Discharge Pipe Insulation Thermal Study"],
  ["Piping Stress Analysis", "Interstage Piping Flexibility Analysis"],
  ["Piping Stress Analysis", "Cooling Water Piping Stress Check"],
  ["Piping Stress Analysis", "Discharge Header Stress Analysis"],
  ["Piping Stress Analysis", "Steam Tracing Line Stress Review"],
  ["Piping Stress Analysis", "Suction Line Nozzle Load Qualification"],
  ["Piping Stress Analysis", "Instrument Air Header Stress Analysis"],
  ["Piping Stress Analysis", "Blowdown Line Dynamic Load Assessment"],
  ["CFD Analysis", "Cooling Tower Plume Dispersion Study"],
  ["CFD Analysis", "Turbo Blower Inlet Duct Optimization"],
  ["Pulsation Study (Pulsim)", "Biogas Compressor Pulsation Assessment"],
  ["Pulsation Study (Pulsim)", "Air Separation Unit Recip Acoustic Review"],
  ["FEA Structural Analysis", "Gearbox Housing Stiffness Analysis"],
  ["FEA Structural Analysis", "Receiver Tank Saddle Support Check"],
  ["Thermal Analysis", "Transformer Room Ventilation Thermal Check"],
  ["Thermal Analysis", "Compressor Valve Cover Thermal Analysis"],
  ["Piping Stress Analysis", "Nitrogen Header Flexibility Study"],
  ["Piping Stress Analysis", "Condensate Return Line Stress Check"],
];

const CUSTOMERS = ["Atlas Process Gas", "Nordic Compressors", "Kirloskar Pneumatic", "Hydro Energy Systems", "Gulf Petrochem", "Sauer Industrial", "Ingersoll Fluid Tech", "EuroGas Solutions"];

const REVERT_NOTES = [
  "Defects found during phase review. Please rework the flagged checkpoints.",
  "Checkpoints marked 'No' need correction before approval.",
  "Inputs not consistent with the job request; please revisit and resubmit.",
  "Please update the model and attach evidence for the flagged items.",
];
const EXECUTOR_REMARKS = ["", "", "Done.", "Verified against input sheet.", "Checked, see report section.", "As per job request.", "Screenshot attached in report."];
const NA_REMARK = "Not applicable for this job.";
const FIXED_PREFIX = "Corrected after review: ";

// ---------------------------------------------------------------------------
// Cleanup of previous demo data
// ---------------------------------------------------------------------------

async function cleanup() {
  const projects = await prisma.project.findMany({
    where: { project_no: { startsWith: PROJECT_NO_PREFIX } },
    select: { id: true },
  });
  const projectIds = projects.map((p) => p.id);
  const emails = EMPLOYEES.map(emailOf);
  const demoUsers = await prisma.user.findMany({ where: { email: { in: emails } }, select: { id: true } });
  const userIds = demoUsers.map((u) => u.id);

  await prisma.$transaction([
    prisma.checklistImage.deleteMany({ where: { project_id: { in: projectIds } } }),
    prisma.checklistApproval.deleteMany({ where: { project_id: { in: projectIds } } }),
    prisma.projectChecklist.deleteMany({ where: { projectId: { in: projectIds } } }),
    prisma.stage.deleteMany({ where: { project_id: { in: projectIds } } }),
    prisma.projectMembership.deleteMany({
      where: { OR: [{ project_id: { in: projectIds } }, { user_id: { in: userIds } }] },
    }),
    prisma.project.deleteMany({ where: { id: { in: projectIds } } }),
    prisma.template.deleteMany({ where: { templateName: { in: TEMPLATES.map((t) => t.templateName) } } }),
  ]);
  // Demo users are kept (and updated in place by createEmployees) so their ids
  // stay stable across runs; a running app holding cached ids keeps working.
  console.log(`Removed previous demo data: ${projectIds.length} projects (kept ${userIds.length} existing demo users).`);
}

// ---------------------------------------------------------------------------
// Seeding steps
// ---------------------------------------------------------------------------

async function ensureRoles() {
  const defs = [
    ["TeamLeader", "Leads the project and owns phase approvals"],
    ["Executor", "Performs the analysis and answers checklist checkpoints"],
    ["Reviewer", "Reviews executor answers and logs defects"],
  ];
  const roles = {};
  for (const [role_name, description] of defs) {
    const existing = await prisma.role.findFirst({ where: { role_name } });
    roles[role_name] = existing ?? (await prisma.role.create({ data: { id: newId(), role_name, description } }));
  }
  return roles;
}

async function createEmployees() {
  const users = {};
  for (const name of EMPLOYEES) {
    const password = await bcrypt.hash(`${firstName(name)}1`, 10);
    users[name] = await prisma.user.upsert({
      where: { email: emailOf(name) },
      update: { name, password, role: "user", status: "active" },
      create: { id: newId(), name, email: emailOf(name), password, role: "user", status: "active" },
    });
  }
  return users;
}

async function createTemplates(adminId) {
  const globalCats = await prisma.globalDefectCategory.findMany();
  if (globalCats.length === 0) throw new Error("No global defect categories found. Open the app once so they get seeded.");
  const catByName = new Map(globalCats.map((c) => [c.name, c]));

  // The checklist UI picks categories from the global list, while the analytics
  // dashboard resolves categoryId via template.defectCategories. Use the same
  // ids in both so defects appear everywhere.
  const defectCategories = globalCats.map((c) => ({
    _id: c.id,
    name: c.name,
    color: "#2196F3",
    group: c.group || "General",
    keywords: Array.isArray(c.keywords) ? c.keywords : [],
  }));
  const groupNames = [...new Set(globalCats.map((c) => c.group || "General"))];

  const result = {};
  for (const t of TEMPLATES) {
    const stageData = {};
    const stageNames = {};
    const meta = []; // per phase: checkpoint metadata in order
    t.phases.forEach((phase, i) => {
      const key = `stage${i + 1}`;
      stageNames[key] = `Phase ${i + 1}`;
      const checkpoints = phase.checkpoints.map((cp) => {
        for (const n of cp.cats) if (!catByName.has(n)) throw new Error(`Unknown defect category "${n}"`);
        return { _id: newId(), text: cp.text, ...{ _meta: cp } };
      });
      meta.push({ checklist: phase.checklist, checkpoints });
      stageData[key] = [
        {
          _id: newId(),
          text: phase.checklist,
          checkpoints: checkpoints.map(({ _id, text }) => ({ _id, text })),
          sections: [],
        },
      ];
    });

    const created = await prisma.template.create({
      data: {
        id: newId(),
        templateName: t.templateName,
        description: t.description,
        isActive: true,
        stageNames,
        stageData,
        defectCategories,
        defectCategoryGroups: groupNames,
        modifiedBy: adminId,
      },
    });
    result[t.templateName] = { template: created, phases: meta, catByName };
  }
  return result;
}

// Build a fresh question exactly like the backend's buildInitialQuestion.
const blankQuestion = (cp) => ({
  _id: cp._id,
  text: cp.text,
  executorAnswer: null,
  executorRemark: "",
  executorImages: [],
  reviewerAnswer: null,
  reviewerStatus: null,
  reviewerRemark: "",
  reviewerImages: [],
  categoryId: "",
  severity: "",
  answeredBy: { executor: null, reviewer: null },
  answeredAt: { executor: null, reviewer: null },
});

/**
 * Simulates the life of one phase checklist.
 *  mode: "pending"            – untouched
 *        "executing"          – executor part way through
 *        "awaiting_review"    – executor submitted, reviewer not yet done
 *        "under_review"       – reviewer answered, open defects present
 *        "reverted"           – just sent back to executor (open iteration)
 *        "approved"           – all agreed, phase approved
 */
function simulatePhase({ phaseMeta, catByName, mode, executorIds, reviewerId, start }) {
  const cps = phaseMeta.checkpoints;
  const group = { groupName: phaseMeta.checklist, defectCount: 0, questions: cps.map((cp) => blankQuestion(cp)), sections: [] };
  const iterations = [];
  let t = start;
  const tick = (h) => (t = addHours(t, h));

  if (mode === "pending") return { groups: [group], iterations, reverts: 0, timeline: {} };

  const naIndex = chance(0.25) ? randInt(0, cps.length - 1) : -1;
  const exec = () => pick(executorIds);

  const executorPass = (onlyIdx = null, partial = false) => {
    group.questions.forEach((q, i) => {
      if (onlyIdx && !onlyIdx.includes(i)) return;
      if (partial && chance(0.45)) return;
      q.executorAnswer = i === naIndex ? "NA" : "Yes";
      q.executorRemark = i === naIndex ? NA_REMARK : pick(EXECUTOR_REMARKS);
      q.answeredBy.executor = exec();
      q.answeredAt.executor = tick(randInt(1, 6)).toISOString();
    });
  };

  const flagDefect = (q, cp) => {
    const meta = cp._meta;
    q.reviewerAnswer = q.executorAnswer === "No" ? "Yes" : "No";
    q.reviewerStatus = "Rejected";
    q.categoryId = catByName.get(pick(meta.cats)).id;
    q.severity = weighted([["Critical", 35], ["Non-Critical", 65]]);
    q.reviewerRemark = pick(meta.remarks);
  };

  const reviewerPass = (defectIdx) => {
    group.questions.forEach((q, i) => {
      if (defectIdx.includes(i)) flagDefect(q, cps[i]);
      else {
        q.reviewerAnswer = q.executorAnswer;
        q.reviewerStatus = "Approved";
        if (!q.reviewerRemark) q.reviewerRemark = "";
      }
      q.answeredBy.reviewer = reviewerId;
      q.answeredAt.reviewer = tick(randInt(1, 4)).toISOString();
    });
  };

  const pickDefects = () => {
    const candidates = cps.map((_, i) => i).filter((i) => i !== naIndex);
    const n = weighted([[1, 82], [2, 18]]);
    return sample(candidates, Math.min(n, candidates.length));
  };

  const revert = (defectIdx) => {
    // Mirrors approval.service revertToExecutor: accumulate, then snapshot.
    group.defectCount += defectIdx.length;
    iterations.push({
      iterationNumber: iterations.length + 1,
      groups: clone([group]),
      revertedAt: tick(2).toISOString(),
      revertedBy: reviewerId,
      revertNotes: pick(REVERT_NOTES),
      executorSubmittedAt: addHours(t, -30).toISOString(),
      reviewerSubmittedAt: addHours(t, -2).toISOString(),
    });
  };

  const fix = (defectIdx) => {
    // Executor reworks; reviewer then agrees. Category/severity stay on the
    // question, as they do in the app after a revert-and-fix cycle.
    defectIdx.forEach((i) => {
      const q = group.questions[i];
      q.executorAnswer = "Yes";
      q.executorRemark = "Updated as per review comment.";
      q.answeredBy.executor = exec();
      q.answeredAt.executor = tick(randInt(2, 8)).toISOString();
      q.reviewerAnswer = "Yes";
      q.reviewerStatus = "Approved";
      q.reviewerRemark = FIXED_PREFIX + q.reviewerRemark;
      q.answeredAt.reviewer = tick(randInt(1, 3)).toISOString();
    });
  };

  if (mode === "executing") {
    executorPass(null, true);
    return { groups: [group], iterations, reverts: 0, timeline: { executorSubmittedAt: null } };
  }

  executorPass();
  const executorSubmittedAt = new Date(t);

  if (mode === "awaiting_review") {
    return { groups: [group], iterations, reverts: 0, timeline: { executorSubmittedAt } };
  }

  // Number of review rounds that ended in a revert before the current state.
  let reverts =
    mode === "approved"
      ? weighted([[0, 58], [1, 35], [2, 7]])
      : mode === "reverted"
        ? weighted([[1, 85], [2, 15]])
        : weighted([[0, 80], [1, 20]]); // under_review

  for (let r = 0; r < reverts; r++) {
    const d = pickDefects();
    reviewerPass(d);
    revert(d);
    if (r < reverts - 1 || mode !== "reverted") fix(d);
  }

  if (mode === "reverted") {
    return { groups: [group], iterations, reverts, timeline: { executorSubmittedAt, reviewerSubmittedAt: new Date(t) } };
  }

  if (mode === "under_review") {
    const d = pickDefects();
    reviewerPass(d);
    return { groups: [group], iterations, reverts, timeline: { executorSubmittedAt, reviewerSubmittedAt: new Date(t) } };
  }

  // approved: final review agrees on every (still-unreviewed) checkpoint
  group.questions.forEach((q) => {
    if (!q.reviewerAnswer) {
      q.reviewerAnswer = q.executorAnswer;
      q.reviewerStatus = "Approved";
      q.answeredBy.reviewer = reviewerId;
      q.answeredAt.reviewer = tick(randInt(1, 3)).toISOString();
    }
  });
  return {
    groups: [group],
    iterations,
    reverts,
    timeline: { executorSubmittedAt, reviewerSubmittedAt: new Date(t), approvedAt: tick(randInt(2, 12)) },
  };
}

// Same formula as projectChecklist.service getOverallDefectRate.
function overallDefectRate(phaseResults) {
  let total = 0;
  for (const { groups, iterations } of phaseResults) {
    const stats = calculateIterationDefectRates(iterations, groups);
    total += stats.iterations.reduce((a, it) => a + (it.defectRate || 0), 0) + (stats.current?.defectRate || 0);
  }
  return parseFloat(total.toFixed(2));
}

async function createProjects({ adminId, users, roles, templates }) {
  const statuses = shuffle([
    ...Array(7).fill("Not Started"),
    ...Array(22).fill("In Progress"),
    ...Array(19).fill("Completed"),
  ]);
  const summary = { "Not Started": 0, "In Progress": 0, Completed: 0, defects: 0, reverts: 0 };

  for (let idx = 0; idx < PROJECTS.length; idx++) {
    const [templateName, projectName] = PROJECTS[idx];
    const status = statuses[idx];
    const tpl = templates[templateName];
    const phaseCount = tpl.phases.length;

    // Timeline
    let start;
    if (status === "Completed") start = addDays(new Date("2026-01-12T09:00:00Z"), randInt(0, 230));
    else if (status === "In Progress") start = addDays(TODAY, -randInt(8, 75));
    else start = addDays(TODAY, randInt(3, 40));
    const durationDays = randInt(18, 55);
    const end = addDays(start, durationDays);

    // Team: 1 TeamLeader, 1-2 Executors, 1 Reviewer (all different people)
    const tl = pick(TEAM_LEADER_POOL);
    const reviewer = pick(REVIEWER_POOL.filter((n) => n !== tl));
    const execCount = weighted([[1, 55], [2, 45]]);
    const executors = sample(EMPLOYEES.filter((n) => n !== tl && n !== reviewer), execCount);

    const project = await prisma.project.create({
      data: {
        id: newId(),
        project_no: `${PROJECT_NO_PREFIX}${1001 + idx}`,
        internal_order_no: `IO-${58200 + randInt(10, 899)}`,
        project_name: projectName,
        description: `${projectName} for ${pick(CUSTOMERS)}. Scope: ${templateName.toLowerCase()} as per job request, with QC review of every phase.`,
        // Stored in the API's snake_case form (the frontend maps these to
        // "Not Started" / "In Progress" / "Completed" and "High"/...).
        status: STATUS_DB[status],
        priority: weighted([["high", 30], ["medium", 45], ["low", 25]]),
        start_date: start,
        end_date: end,
        templateName,
        isReviewApplicable: "yes",
        created_by: adminId,
        createdAt: addDays(start, -randInt(1, 6)),
      },
    });
    summary[status]++;

    await prisma.projectMembership.createMany({
      data: [
        { project_id: project.id, user_id: users[tl].id, role_id: roles.TeamLeader.id },
        ...executors.map((n) => ({ project_id: project.id, user_id: users[n].id, role_id: roles.Executor.id })),
        { project_id: project.id, user_id: users[reviewer].id, role_id: roles.Reviewer.id },
      ],
    });

    if (status === "Not Started") continue; // the app creates phases only once a project starts

    // Decide each phase's mode
    let currentPhase = phaseCount + 1; // completed => all approved
    if (status === "In Progress") currentPhase = randInt(1, phaseCount);
    const inProgressMode = weighted([
      ["executing", 25],
      ["awaiting_review", 20],
      ["under_review", 30],
      ["reverted", 25],
    ]);

    const executorIds = executors.map((n) => users[n].id);
    const reviewerId = users[reviewer].id;
    const phaseResults = [];
    let phaseStart = addHours(start, 4);

    for (let p = 1; p <= phaseCount; p++) {
      const mode = p < currentPhase ? "approved" : p === currentPhase ? inProgressMode : "pending";
      const res = simulatePhase({
        phaseMeta: tpl.phases[p - 1],
        catByName: tpl.catByName,
        mode,
        executorIds,
        reviewerId,
        start: phaseStart,
      });
      phaseResults.push(res);
      summary.reverts += res.reverts;
      phaseStart = addDays(phaseStart, Math.max(2, Math.floor(durationDays / phaseCount)));

      const stageKey = `stage${p}`;
      const stageStatus = mode === "approved" ? "completed" : mode === "pending" ? "pending" : "in_progress";
      const stage = await prisma.stage.create({
        data: {
          id: newId(),
          project_id: project.id,
          stage_name: `Phase ${p}`,
          stage_key: stageKey,
          status: stageStatus,
          created_by: adminId,
          conflict_count: res.reverts,
          createdAt: addHours(start, p), // keeps phase order stable (stages are sorted by createdAt)
        },
      });

      await prisma.projectChecklist.create({
        data: {
          id: newId(),
          projectId: project.id,
          stageId: stage.id,
          stage: stageKey,
          groups: res.groups,
          iterations: res.iterations,
          currentIteration: res.iterations.length + 1,
        },
      });

      // Approval record
      const tl_ = res.timeline;
      let approval = null;
      if (mode === "approved") {
        approval = { status: "approved", decided_at: tl_.approvedAt, decided_by: reviewerId, executor_submitted: true, executor_submitted_at: tl_.executorSubmittedAt, reviewer_submitted: true, reviewer_submitted_at: tl_.reviewerSubmittedAt, notes: "" };
      } else if (mode === "awaiting_review") {
        approval = { status: "pending", executor_submitted: true, executor_submitted_at: tl_.executorSubmittedAt, notes: "" };
      } else if (mode === "under_review") {
        approval = { status: "pending", executor_submitted: true, executor_submitted_at: tl_.executorSubmittedAt, reviewer_submitted: true, reviewer_submitted_at: tl_.reviewerSubmittedAt, notes: "" };
      } else if (mode === "reverted") {
        const last = res.iterations[res.iterations.length - 1];
        approval = { status: "reverted_to_executor", decided_at: new Date(last.revertedAt), decided_by: reviewerId, executor_submitted: false, reviewer_submitted: false, notes: last.revertNotes };
      }
      if (approval) {
        await prisma.checklistApproval.create({
          data: { id: newId(), project_id: project.id, phase: p, revertCount: res.reverts, requested_at: tl_.executorSubmittedAt ?? phaseStart, ...approval },
        });
      }
    }

    // Count defects for the summary (current open + historical)
    for (const r of phaseResults) {
      summary.defects += calculateCurrentMismatches(r.groups).totalDefects;
      for (const it of r.iterations) summary.defects += calculateCurrentMismatches(it.groups).totalDefects;
    }

    await prisma.project.update({
      where: { id: project.id },
      data: { overallDefectRate: overallDefectRate(phaseResults) },
    });
    process.stdout.write(".");
  }
  process.stdout.write("\n");
  return summary;
}

// ---------------------------------------------------------------------------

async function main() {
  const admin = await prisma.user.findFirst({ where: { role: "admin" }, orderBy: { createdAt: "asc" } });
  if (!admin) throw new Error("No admin user found. Run `node -r dotenv/config seed.js` first.");

  await cleanup();
  const roles = await ensureRoles();
  const users = await createEmployees();
  console.log(`Created ${EMPLOYEES.length} employees.`);
  const templates = await createTemplates(admin.id);
  console.log(`Created ${TEMPLATES.length} templates.`);
  const s = await createProjects({ adminId: admin.id, users, roles, templates });
  console.log(
    `Created ${PROJECTS.length} projects (Not Started ${s["Not Started"]}, In Progress ${s["In Progress"]}, Completed ${s.Completed}); ` +
      `${s.defects} defects logged, ${s.reverts} phase reverts.`,
  );
  console.log("\nEmployee logins:");
  for (const n of EMPLOYEES) console.log(`  ${n.padEnd(16)} ${emailOf(n).padEnd(22)} ${firstName(n)}1`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
