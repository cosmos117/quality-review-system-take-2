import express from "express";
const router = express.Router();
import multer from "multer";
const upload = multer();
import {
  init,
  uploadImage,
  getImagesByQuestion,
  getImagesByQuestionAndRole,
  downloadImageById,
  deleteImageById,
  getFileMetadata,
} from "../gridfs.js";

// GridFS initialization is deferred until the first request,
// because Mongoose must be connected first (see gridfs.js).
// The init() function is idempotent and fast after the first call.
let gridfsReady = false;
async function ensureGridFS() {
  if (!gridfsReady) {
    await init();
    gridfsReady = true;
  }
}

// Upload image for a questionId with role (executor or reviewer)
// POST /images/:questionId?role=executor or /images/:questionId?role=reviewer
router.post("/images/:questionId", upload.single("image"), async (req, res) => {
  try {
    await ensureGridFS();
    const { questionId } = req.params;
    const { role } = req.query; // Get role from query parameter
    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ error: "No image file provided" });
    }
    if (role && !["executor", "reviewer"].includes(role)) {
      return res
        .status(400)
        .json({ error: "Invalid role. Must be executor or reviewer" });
    }
    const file = await uploadImage(
      questionId,
      req.file.buffer,
      req.file.originalname || "upload.jpg",
      req.file.mimetype || "image/jpeg",
      role, // Pass role to store in metadata
    );
    return res.status(201).json({ fileId: file?.id, filename: file?.filename });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// List images by questionId and optionally by role
// GET /images/:questionId?role=executor or /images/:questionId?role=reviewer
router.get("/images/:questionId", async (req, res) => {
  try {
    await ensureGridFS();
    const { questionId } = req.params;
    const { role } = req.query;

    let files;
    if (role && ["executor", "reviewer"].includes(role)) {
      files = await getImagesByQuestionAndRole(questionId, role);
    } else {
      files = await getImagesByQuestion(questionId);
    }

    return res.json(
      files.map((f) => ({
        _id: f._id,
        filename: f.filename,
        length: f.length,
        uploadDate: f.uploadDate,
        contentType: f.contentType,
        role: f.metadata?.role, // Include role in response
      })),
    );
  } catch (e) {

    return res.status(500).json({ error: e.message });
  }
});

// Download by file id
router.get("/images/file/:fileId", async (req, res) => {
  try {
    await ensureGridFS();
    // Get file metadata to set correct headers
    const fileDoc = await getFileMetadata(req.params.fileId);

    // If file doesn't exist, return 404 immediately
    if (!fileDoc) {
      return res.status(404).json({ error: "File not found" });
    }

    const contentType =
      fileDoc.metadata?.contentType ||
      fileDoc.contentType ||
      "application/octet-stream";
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

export default router;
