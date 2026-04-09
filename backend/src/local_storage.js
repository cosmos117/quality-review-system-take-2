import fs from "fs/promises";
import { createReadStream, existsSync } from "fs";
import path from "path";
import { v4 as uuidv4 } from "uuid";
import logger from "./utils/logger.js";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const UPLOADS_DIR = path.join(__dirname, "..", "uploads");
const METADATA_DIR = path.join(__dirname, "..", "uploads_metadata");

async function init() {
  await fs.mkdir(UPLOADS_DIR, { recursive: true });
  await fs.mkdir(METADATA_DIR, { recursive: true });
  logger.info(`Local storage initialized at ${UPLOADS_DIR}`);
  return true;
}

async function uploadImage(questionId, buffer, filename, contentType, role = null) {
  const fileId = uuidv4();
  const filePath = path.join(UPLOADS_DIR, fileId);
  const metadataPath = path.join(METADATA_DIR, `${fileId}.json`);

  const metadata = {
    _id: fileId,
    filename,
    contentType,
    length: buffer.length,
    uploadDate: new Date().toISOString(),
    metadata: {
      questionId,
      ...(role ? { role } : {})
    }
  };

  await fs.writeFile(filePath, buffer);
  await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));

  return { id: fileId, filename };
}

async function getAllMetadata() {
  const files = await fs.readdir(METADATA_DIR).catch(() => []);
  const metadataList = [];
  for (const file of files) {
    if (file.endsWith('.json')) {
      try {
        const content = await fs.readFile(path.join(METADATA_DIR, file), 'utf-8');
        metadataList.push(JSON.parse(content));
      } catch (e) {
        // ignore parsing errors
      }
    }
  }
  return metadataList;
}

async function getImagesByQuestion(questionId) {
  const allMetadata = await getAllMetadata();
  return allMetadata.filter(m => m.metadata?.questionId === questionId);
}

async function getImagesByQuestionAndRole(questionId, role) {
  const allMetadata = await getAllMetadata();
  return allMetadata.filter(m => {
    if (m.metadata?.questionId !== questionId) return false;
    if (role === "executor") {
      return !m.metadata.role || m.metadata.role === "executor";
    }
    return m.metadata.role === role;
  });
}

// Ensure the returned stream resolves correctly like MongoDB's streams
async function downloadImageById(fileId) {
  const filePath = path.join(UPLOADS_DIR, fileId);
  if (!existsSync(filePath)) throw new Error("File not found");
  return createReadStream(filePath);
}

async function deleteImageById(fileId) {
  const filePath = path.join(UPLOADS_DIR, fileId);
  const metadataPath = path.join(METADATA_DIR, `${fileId}.json`);
  
  try { await fs.unlink(filePath); } catch (e) {}
  try { await fs.unlink(metadataPath); } catch (e) {}
}

async function deleteImagesByFileIds(fileIds) {
  const promises = fileIds.map(id => deleteImageById(id));
  return Promise.allSettled(promises);
}

async function getFileMetadata(fileId) {
  const metadataPath = path.join(METADATA_DIR, `${fileId}.json`);
  try {
    const content = await fs.readFile(metadataPath, 'utf-8');
    return JSON.parse(content);
  } catch (e) {
    return null;
  }
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
