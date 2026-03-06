import { GridFSBucket, ObjectId } from "mongodb";
import mongoose from "mongoose";

let db;
let bucket;

/**
 * Initialize GridFS using Mongoose's existing connection.
 * This ensures GridFS uses the exact same database as all other Mongoose models,
 * so images stored via GridFS are always accessible from any backend instance
 * connected to the same MongoDB.
 *
 * Call this AFTER mongoose.connect() has resolved.
 */
async function init() {
  if (bucket) return bucket;

  // Reuse Mongoose's native MongoDB connection — guarantees same DB
  const conn = mongoose.connection;
  if (!conn || conn.readyState !== 1) {
    throw new Error(
      "Mongoose is not connected. Call init() after mongoose.connect() resolves.",
    );
  }

  db = conn.db; // same database Mongoose uses
  bucket = new GridFSBucket(db, { bucketName: "uploads" });
  console.log(
    `✅ GridFS initialized on database "${db.databaseName}" (shared with Mongoose)`,
  );
  return bucket;
}

async function uploadImage(
  questionId,
  buffer,
  filename,
  contentType,
  role = null,
) {
  if (!bucket) throw new Error("GridFS not initialized");
  return new Promise((resolve, reject) => {
    const metadata = { questionId, contentType };
    if (role) metadata.role = role; // Store role (executor or reviewer)
    const uploadStream = bucket.openUploadStream(filename, { metadata });
    uploadStream.on("error", (err) => reject(err));
    uploadStream.on("finish", () => {
      // Use uploadStream.id provided by the driver - convert to string
      resolve({ id: uploadStream.id.toString(), filename });
    });
    uploadStream.end(buffer);
  });
}

async function getImagesByQuestion(questionId) {
  if (!bucket) throw new Error("GridFS not initialized");
  const cursor = bucket.find({ "metadata.questionId": questionId });
  return cursor.toArray();
}

async function getImagesByQuestionAndRole(questionId, role) {
  if (!bucket) throw new Error("GridFS not initialized");
  // Query for images with the specific role OR with no role (backward compatibility - treat as executor)
  const query =
    role === "executor"
      ? {
          "metadata.questionId": questionId,
          $or: [
            { "metadata.role": "executor" },
            { "metadata.role": { $exists: false } }, // Old images without role are treated as executor images
          ],
        }
      : {
          "metadata.questionId": questionId,
          "metadata.role": role,
        };
  const cursor = bucket.find(query);
  return cursor.toArray();
}

async function downloadImageById(fileId) {
  if (!bucket) throw new Error("GridFS not initialized");
  return bucket.openDownloadStream(new ObjectId(fileId));
}
async function deleteImageById(fileId) {
  if (!bucket) throw new Error("GridFS not initialized");
  return bucket.delete(new ObjectId(fileId));
}

async function deleteImagesByFileIds(fileIds) {
  if (!bucket) throw new Error("GridFS not initialized");
  const deletePromises = fileIds.map((fileId) => {
    try {
      return bucket.delete(new ObjectId(fileId));
    } catch (err) {
      return null;
    }
  });
  return Promise.allSettled(deletePromises);
}

async function getFileMetadata(fileId) {
  if (!db) throw new Error("GridFS not initialized");
  return db.collection("uploads.files").findOne({ _id: new ObjectId(fileId) });
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
