import express from "express";
const router = express.Router();
import multer from "multer";
import path from "path";
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png"]);
const ALLOWED_EXTENSIONS = new Set([".jpg", ".jpeg", ".png"]);
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname((file.originalname || "").toLowerCase());
    const mimeAllowed = ALLOWED_MIME_TYPES.has(
      (file.mimetype || "").toLowerCase(),
    );
    const extAllowed = ALLOWED_EXTENSIONS.has(ext);
    // Flutter web often sends application/octet-stream; allow by trusted extension
    // and validate the actual bytes later in handleUpload.
    if (!mimeAllowed && !extAllowed) {
      return cb(new Error("Only JPG and PNG images are allowed"));
    }
    return cb(null, true);
  },
});

import {
  init,
  uploadImage,
  getImagesByQuestion,
  getImagesByQuestionAndRole,
  downloadImageById,
  deleteImageById,
  getFileMetadata,
} from "../local_storage.js";

// Initialization is deferred until the first request.
// The init() function is idempotent and fast after the first call.
let gridfsReady = false;
async function ensureGridFS() {
  if (!gridfsReady) {
    await init();
    gridfsReady = true;
  }
}

function parseMeta(req, questionIdFromPath = null) {
  const questionId =
    questionIdFromPath ||
    (req.body?.question_id || req.body?.questionId || "").toString().trim();
  const projectId = (req.body?.project_id || req.body?.projectId || "")
    .toString()
    .trim();
  const checklistId = (req.body?.checklist_id || req.body?.checklistId || "")
    .toString()
    .trim();
  const defectId = (req.body?.defect_id || req.body?.defectId || "")
    .toString()
    .trim();
  const role = (req.body?.role || req.query?.role || "").toString().trim();

  return {
    questionId,
    projectId,
    checklistId,
    defectId,
    role,
    userId:
      req.user?._id ||
      req.user?.id ||
      (req.body?.user_id || req.body?.userId || "").toString().trim() ||
      null,
  };
}

function isValidRole(role) {
  return !role || ["executor", "reviewer"].includes(role.toLowerCase());
}

function toImageResponse(req, file) {
  const safePath = file.imagePath || file.image_path || "";
  const hostUrl = `${req.protocol}://${req.get("host")}`;
  const absoluteUrl = safePath
    ? `${hostUrl}${safePath.startsWith("/") ? "" : "/"}${safePath}`
    : null;

  return {
    id: file._id || file.id,
    fileId: file._id || file.id,
    filename: file.filename,
    length: file.length,
    uploadDate: file.uploadDate,
    contentType: file.contentType,
    role: file.metadata?.role,
    question_id: file.metadata?.questionId || null,
    defect_id: file.metadata?.defectId || null,
    image_path: safePath,
    image_url: absoluteUrl,
  };
}

function handleMulterError(err, _req, res, next) {
  if (err instanceof multer.MulterError) {
    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({
        error: `Image size exceeds ${MAX_FILE_SIZE_BYTES / (1024 * 1024)}MB limit`,
      });
    }
    return res.status(400).json({ error: err.message });
  }

  if (err && err.message) {
    return res.status(400).json({ error: err.message });
  }

  return next(err);
}

function inferImageMimeFromBuffer(buffer) {
  if (!buffer || buffer.length < 4) return null;

  // JPEG SOI marker: FF D8
  if (buffer[0] === 0xff && buffer[1] === 0xd8) {
    return "image/jpeg";
  }

  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return "image/png";
  }

  return null;
}

async function handleUpload(req, res, questionIdFromPath = null) {
  await ensureGridFS();

  if (!req.file || !req.file.buffer) {
    return res.status(400).json({ error: "No image file provided" });
  }

  const meta = parseMeta(req, questionIdFromPath);
  if (!meta.questionId) {
    return res.status(400).json({ error: "question_id is required" });
  }

  if (!isValidRole(meta.role)) {
    return res
      .status(400)
      .json({ error: "Invalid role. Must be executor or reviewer" });
  }

  const inferredMimeType = inferImageMimeFromBuffer(req.file.buffer);
  if (!inferredMimeType) {
    return res.status(400).json({ error: "Invalid image file content" });
  }

  const requestMimeType = (req.file.mimetype || "").toLowerCase();
  const finalMimeType = ALLOWED_MIME_TYPES.has(requestMimeType)
    ? requestMimeType
    : inferredMimeType;

  const file = await uploadImage(
    meta.questionId,
    req.file.buffer,
    req.file.originalname || "upload.jpg",
    finalMimeType,
    meta.role || null,
    {
      projectId: meta.projectId || null,
      checklistId: meta.checklistId || null,
      defectId: meta.defectId || null,
      userId: meta.userId,
    },
  );

  return res.status(201).json({
    id: file.id,
    fileId: file.id,
    filename: file.filename,
    image_path: file.image_path,
    image_url: `${req.protocol}://${req.get("host")}${
      file.image_url?.startsWith("/") ? "" : "/"
    }${file.image_url || ""}`,
  });
}

// New endpoint requested by product requirement.
router.post("/upload-image", upload.single("image"), async (req, res, next) => {
  try {
    return await handleUpload(req, res);
  } catch (e) {
    return next(e);
  }
});

// Backward-compatible upload endpoint used by current Flutter app.
// POST /images/:questionId?role=executor or /images/:questionId?role=reviewer
router.post("/images/:questionId", upload.single("image"), async (req, res) => {
  try {
    return await handleUpload(req, res, req.params.questionId);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// List images for a question. Supports optional role filter.
// GET /images/:questionId
router.get("/images/:questionId", async (req, res) => {
  try {
    await ensureGridFS();
    const { questionId } = req.params;
    const role = (req.query?.role || "").toString().trim().toLowerCase();

    if (!isValidRole(role)) {
      return res
        .status(400)
        .json({ error: "Invalid role. Must be executor or reviewer" });
    }

    let files;
    if (role) {
      files = await getImagesByQuestionAndRole(questionId, role);
    } else {
      files = await getImagesByQuestion(questionId);
    }

    return res.json(files.map((f) => toImageResponse(req, f)));
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// Download by file id for backward compatibility with current UI.
router.get("/images/file/:fileId", async (req, res) => {
  try {
    await ensureGridFS();
    // Get file metadata to set correct headers
    const fileDoc = await getFileMetadata(req.params.fileId);

    // If file doesn't exist, return 404 immediately
    if (!fileDoc) {
      return res.status(404).json({ error: "File not found" });
    }

    const contentType = fileDoc.contentType || "application/octet-stream";
    res.setHeader("Content-Type", contentType);
    res.setHeader("Content-Length", fileDoc.length);

    const stream = await downloadImageById(req.params.fileId);
    stream.on("error", (err) => {
      if (!res.headersSent) {
        res.status(404).json({ error: "File not found" });
      }
    });
    stream.pipe(res);
  } catch (e) {
    // Check if it's a file not found error
    if (
      e.code === "ENOENT" ||
      String(e?.message || "")
        .toLowerCase()
        .includes("not found")
    ) {
      if (!res.headersSent) {
        return res.status(404).json({ error: "File not found" });
      }
    }
    if (!res.headersSent) {
      return res.status(500).json({ error: e.message });
    }
  }
});

// Delete by file id
router.delete("/images/file/:fileId", async (req, res) => {
  try {
    await ensureGridFS();
    const { fileId } = req.params;
    await deleteImageById(fileId);
    return res.status(204).end();
  } catch (e) {
    // If not found, Mongo throws, respond 404
    if (
      String(e?.message || "")
        .toLowerCase()
        .includes("not found")
    ) {
      return res.status(404).json({ error: "File not found" });
    }
    return res.status(500).json({ error: e.message });
  }
});

router.use(handleMulterError);

export default router;
