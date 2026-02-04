import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

const MONGODB_URI = process.env.MONGO_DB_URI;
const DB_NAME = process.env.DB_NAME || "authdb";

await mongoose.connect(MONGODB_URI, { dbName: DB_NAME });
console.log("✓ Connected to MongoDB");
console.log(`✓ Database: ${DB_NAME}\n`);

const db = mongoose.connection.db;
const collections = await db.listCollections().toArray();

console.log("Available collections:");
collections.forEach((col) => {
  console.log(`  - ${col.name}`);
});

// Check projectchecklists specifically
const projectChecklistsCollection = db.collection("projectchecklists");
const count = await projectChecklistsCollection.countDocuments();
console.log(`\nProjectChecklists collection: ${count} documents`);

if (count > 0) {
  const sample = await projectChecklistsCollection.findOne({});
  console.log("\nSample document:");
  console.log(JSON.stringify(sample, null, 2));
}

await mongoose.disconnect();
console.log("\n✓ Disconnected");
