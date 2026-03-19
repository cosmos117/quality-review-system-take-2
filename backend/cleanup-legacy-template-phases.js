import mongoose from "mongoose";
import dotenv from "dotenv";
import Template from "./src/models/template.models.js";

dotenv.config();

const DRY_RUN = String(process.env.DRY_RUN || "false").toLowerCase() === "true";
const TARGET_TEMPLATE = (process.env.TEMPLATE_NAME || "").trim();
const REKEY_ALL =
  String(process.env.REKEY_ALL || "false").toLowerCase() === "true";

function isStageKey(key) {
  return /^stage\d{1,2}$/.test(key);
}

function asText(value, fallback = "") {
  if (typeof value === "string") return value.trim();
  if (value == null) return fallback;
  return String(value).trim();
}

function ensureObjectId(value) {
  if (REKEY_ALL) {
    return new mongoose.Types.ObjectId();
  }
  if (value && mongoose.Types.ObjectId.isValid(value)) {
    return new mongoose.Types.ObjectId(value);
  }
  return new mongoose.Types.ObjectId();
}

function normalizeCheckpoint(cp) {
  if (typeof cp === "string") {
    return {
      _id: new mongoose.Types.ObjectId(),
      text: cp.trim(),
    };
  }

  const text = asText(cp?.text ?? cp?.question ?? cp?.name, "");
  const categoryId = cp?.categoryId ? asText(cp.categoryId, "") : undefined;

  return {
    _id: ensureObjectId(cp?._id),
    text,
    ...(categoryId ? { categoryId } : {}),
  };
}

function normalizeSection(section) {
  const text = asText(
    section?.text ?? section?.sectionName ?? section?.name,
    "",
  );
  const rawCheckpoints = Array.isArray(section?.checkpoints)
    ? section.checkpoints
    : Array.isArray(section?.questions)
      ? section.questions
      : [];

  return {
    _id: ensureObjectId(section?._id),
    text,
    checkpoints: rawCheckpoints
      .map(normalizeCheckpoint)
      .filter((cp) => cp.text),
  };
}

function normalizeGroup(group) {
  if (typeof group === "string") {
    return {
      _id: new mongoose.Types.ObjectId(),
      text: group.trim(),
      checkpoints: [],
      sections: [],
    };
  }

  const text = asText(
    group?.text ?? group?.groupName ?? group?.checklist_name ?? group?.name,
    "",
  );

  const rawCheckpoints = Array.isArray(group?.checkpoints)
    ? group.checkpoints
    : Array.isArray(group?.questions)
      ? group.questions
      : [];

  const rawSections = Array.isArray(group?.sections) ? group.sections : [];

  return {
    _id: ensureObjectId(group?._id),
    text,
    checkpoints: rawCheckpoints
      .map(normalizeCheckpoint)
      .filter((cp) => cp.text),
    sections: rawSections.map(normalizeSection).filter((sec) => sec.text),
  };
}

function normalizeStageData(stageData) {
  if (!Array.isArray(stageData)) {
    return { normalized: [], changed: stageData != null };
  }

  let changed = false;
  const normalized = stageData
    .map((group) => {
      const before = JSON.stringify(group ?? null);
      const afterObj = normalizeGroup(group);
      const after = JSON.stringify(afterObj);
      if (before !== after) changed = true;
      return afterObj;
    })
    .filter((group) => group.text);

  if (normalized.length !== stageData.length) changed = true;
  return { normalized, changed };
}

async function run() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error("MONGODB_URI is not defined");
  }

  await mongoose.connect(mongoUri);

  const query = TARGET_TEMPLATE ? { templateName: TARGET_TEMPLATE } : {};
  const templates = await Template.find(query);

  if (!templates.length) {
    console.log("No templates found for query", query);
    await mongoose.disconnect();
    return;
  }

  let templatesUpdated = 0;
  let stagesUpdated = 0;

  for (const template of templates) {
    const doc = template.toObject({ flattenMaps: true });
    const stageKeys = Object.keys(doc).filter(isStageKey);

    let templateChanged = false;
    const updateSet = {};

    for (const stageKey of stageKeys) {
      const { normalized, changed } = normalizeStageData(template[stageKey]);
      if (changed || REKEY_ALL) {
        updateSet[stageKey] = normalized;
        templateChanged = true;
        stagesUpdated += 1;
      }
    }

    if (templateChanged) {
      templatesUpdated += 1;
      if (!DRY_RUN) {
        await Template.updateOne({ _id: template._id }, { $set: updateSet });
      }
      console.log(
        `${DRY_RUN ? "[DRY-RUN] " : ""}Template updated: ${template.templateName || "<legacy-default>"} | stages: ${Object.keys(updateSet).join(", ")}`,
      );
    }
  }

  console.log("--- Migration Summary ---");
  console.log(`Dry run: ${DRY_RUN}`);
  console.log(`Rekey all IDs: ${REKEY_ALL}`);
  console.log(`Target template: ${TARGET_TEMPLATE || "<all>"}`);
  console.log(`Templates scanned: ${templates.length}`);
  console.log(`Templates needing update: ${templatesUpdated}`);
  console.log(`Stages normalized: ${stagesUpdated}`);

  await mongoose.disconnect();
}

run().catch(async (err) => {
  console.error("Migration failed:", err);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
