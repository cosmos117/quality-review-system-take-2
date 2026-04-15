import fs from "fs/promises";
import { createReadStream, existsSync } from "fs";
import path from "path";
import { randomBytes } from "crypto";
import { fileURLToPath } from "url";
import prisma from "./config/prisma.js";
import logger from "./utils/logger.js";
import { newId } from "./utils/newId.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const BACKEND_ROOT = path.join(__dirname, "..");
const UPLOADS_DIR = path.join(BACKEND_ROOT, "uploads");

function toStringOrEmpty(value) {
  if (value === undefined || value === null) return "";
  return String(value).trim();
}

function extractFileId(value) {
  if (typeof value === "string") return toStringOrEmpty(value);
  if (value && typeof value === "object") {
    return toStringOrEmpty(value.fileId || value.id || value._id);
  }
  return toStringOrEmpty(value);
}

function sanitizePathSegment(value, fallback) {
  const cleaned = toStringOrEmpty(value)
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  return cleaned || fallback;
}

function normalizeRole(role) {
  const r = toStringOrEmpty(role).toLowerCase();
  if (!r) return null;
  if (r === "executor" || r === "reviewer") return r;
  return null;
}

function detectExtension(originalName, contentType) {
  const ext = path.extname(toStringOrEmpty(originalName)).toLowerCase();
  if (ext === ".jpg" || ext === ".jpeg" || ext === ".png") {
    return ext === ".jpeg" ? ".jpg" : ext;
  }
  if (contentType === "image/png") return ".png";
  return ".jpg";
}

function uniqueFilename(originalName, contentType) {
  const ts = Date.now();
  const rand = randomBytes(6).toString("hex");
  const ext = detectExtension(originalName, contentType);
  return `${ts}-${rand}${ext}`;
}

async function resolveChecklistId(projectId, checklistId) {
  const pid = toStringOrEmpty(projectId);
  const cid = toStringOrEmpty(checklistId);

  if (!pid || !cid) return null;

  const exact = await prisma.projectChecklist.findUnique({
    where: { id: cid },
    select: { id: true, projectId: true },
  });
  if (exact && exact.projectId === pid) return exact.id;

  const byStage = await prisma.projectChecklist.findUnique({
    where: { projectId_stageId: { projectId: pid, stageId: cid } },
    select: { id: true },
  });
  if (byStage) return byStage.id;

  return cid;
}

function buildPublicImageUrl(relativePath) {
  const normalized = toStringOrEmpty(relativePath).replace(/\\/g, "/");
  return normalized.startsWith("/") ? normalized : `/${normalized}`;
}

function toAbsolutePath(imagePath) {
  const normalized = toStringOrEmpty(imagePath).replace(/\//g, path.sep);
  return path.join(BACKEND_ROOT, normalized);
}

function mapRecordToLegacyMetadata(record) {
  const uploadDate =
    record.created_at instanceof Date
      ? record.created_at.toISOString()
      : new Date(record.created_at).toISOString();

  return {
    _id: record.id,
    filename: record.original_name || path.basename(record.image_path),
    length: record.size_bytes || 0,
    uploadDate,
    contentType: record.mime_type || "application/octet-stream",
    contentTypeResolved: record.mime_type || "application/octet-stream",
    imagePath: record.image_path,
    imageUrl: buildPublicImageUrl(record.image_path),
    metadata: {
      questionId: record.question_id,
      role: record.role || null,
      defectId: record.defect_id || null,
      projectId: record.project_id || null,
      checklistId: record.checklist_id || null,
      uploadedBy: record.uploaded_by || null,
    },
  };
}

async function init() {
  await fs.mkdir(UPLOADS_DIR, { recursive: true });
  logger.info(`Image storage initialized at ${UPLOADS_DIR}`);
  return true;
}

async function uploadImage(
  questionId,
  buffer,
  filename,
  contentType,
  role = null,
  metadata = {},
) {
  const qidRaw = toStringOrEmpty(questionId);
  if (!qidRaw) throw new Error("questionId is required");

  const projectId = toStringOrEmpty(metadata.projectId) || null;
  const resolvedChecklistId = await resolveChecklistId(
    projectId,
    metadata.checklistId,
  );
  const defectId = toStringOrEmpty(metadata.defectId) || null;
  const uploadedBy = toStringOrEmpty(metadata.userId) || null;
  const normalizedRole = normalizeRole(role);

  const projectSegment = sanitizePathSegment(projectId, "unknown_project");
  const checklistSegment = sanitizePathSegment(
    resolvedChecklistId,
    "unknown_checklist",
  );
  const questionSegment = sanitizePathSegment(qidRaw, "unknown_question");

  const fileName = uniqueFilename(filename, contentType);
  const relativePath = path
    .join(
      "uploads",
      projectSegment,
      checklistSegment,
      questionSegment,
      fileName,
    )
    .replace(/\\/g, "/");
  const absolutePath = toAbsolutePath(relativePath);

  await fs.mkdir(path.dirname(absolutePath), { recursive: true });
  await fs.writeFile(absolutePath, buffer);

  const id = newId();
  const created = await prisma.checklistImage.create({
    data: {
      id,
      project_id: projectId,
      checklist_id: resolvedChecklistId,
      defect_id: defectId,
      question_id: qidRaw,
      image_path: relativePath,
      uploaded_by: uploadedBy,
      role: normalizedRole,
      original_name: toStringOrEmpty(filename) || fileName,
      mime_type: contentType || "application/octet-stream",
      size_bytes: buffer.length,
    },
  });

  return {
    id: created.id,
    filename: created.original_name || fileName,
    image_path: created.image_path,
    image_url: buildPublicImageUrl(created.image_path),
  };
}

async function getImagesByQuestion(questionId) {
  const qid = toStringOrEmpty(questionId);
  if (!qid) return [];

  const records = await prisma.checklistImage.findMany({
    where: { question_id: qid },
    orderBy: { created_at: "desc" },
  });

  return records.map(mapRecordToLegacyMetadata);
}

async function getImagesByQuestionAndRole(questionId, role) {
  const qid = toStringOrEmpty(questionId);
  const normalizedRole = normalizeRole(role);
  if (!qid) return [];
  if (!normalizedRole) return getImagesByQuestion(qid);

  const where =
    normalizedRole === "executor"
      ? {
          question_id: qid,
          OR: [{ role: null }, { role: "" }, { role: "executor" }],
        }
      : {
          question_id: qid,
          role: normalizedRole,
        };

  const records = await prisma.checklistImage.findMany({
    where,
    orderBy: { created_at: "desc" },
  });

  return records.map(mapRecordToLegacyMetadata);
}

async function getFileMetadata(fileId) {
  const id = extractFileId(fileId);
  if (!id) return null;

  const record = await prisma.checklistImage.findUnique({ where: { id } });
  if (!record) return null;

  const metadata = mapRecordToLegacyMetadata(record);
  return {
    ...metadata,
    id: record.id,
    contentType: record.mime_type || "application/octet-stream",
  };
}

async function downloadImageById(fileId) {
  const metadata = await getFileMetadata(fileId);
  if (!metadata) throw new Error("File not found");

  const absolutePath = toAbsolutePath(metadata.imagePath);
  if (!existsSync(absolutePath)) throw new Error("File not found");
  return createReadStream(absolutePath);
}

async function deleteImageById(fileId) {
  const id = extractFileId(fileId);
  if (!id) return;

  const record = await prisma.checklistImage.findUnique({ where: { id } });
  if (!record) throw new Error("File not found");

  await prisma.checklistImage.delete({ where: { id } });

  const absolutePath = toAbsolutePath(record.image_path);
  await fs.unlink(absolutePath).catch(() => {});
}

async function deleteImagesByFileIds(fileIds) {
  const safeIds = Array.isArray(fileIds)
    ? [...new Set(fileIds.map((id) => extractFileId(id)).filter(Boolean))]
    : [];

  const promises = safeIds.map((id) => deleteImageById(id));
  return Promise.allSettled(promises);
}

export {
  init,
  uploadImage,
  getImagesByQuestion,
  getImagesByQuestionAndRole,
  downloadImageById,
  deleteImageById,
  deleteImagesByFileIds,
  getFileMetadata,
};
