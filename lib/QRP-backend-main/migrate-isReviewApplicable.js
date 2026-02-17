/**
 * Migration script to add isReviewApplicable field to existing projects
 * Run with: node migrate-isReviewApplicable.js
 */

import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config({ path: "./.env" });

const MONGODB_URI = process.env.MONGO_DB_URI;
const DB_NAME = process.env.DB_NAME || "authdb";

async function migrateIsReviewApplicable() {
  try {
    await mongoose.connect(MONGODB_URI, { dbName: DB_NAME });
    console.log("✓ Connected to MongoDB");
    console.log(`✓ Using database: ${DB_NAME}\n`);

    const db = mongoose.connection.db;
    const projectsCollection = db.collection("projects");

    // Count projects without isReviewApplicable field
    const projectsWithoutField = await projectsCollection.countDocuments({
      isReviewApplicable: { $exists: false },
    });

    console.log(
      `Found ${projectsWithoutField} projects without isReviewApplicable field\n`,
    );

    if (projectsWithoutField === 0) {
      console.log("✓ All projects already have the isReviewApplicable field");
      await mongoose.disconnect();
      process.exit(0);
    }

    // Update all projects without the field to set it to null
    const result = await projectsCollection.updateMany(
      { isReviewApplicable: { $exists: false } },
      { $set: { isReviewApplicable: null } },
    );

    console.log(`✓ Updated ${result.modifiedCount} projects`);
    console.log("✓ Migration completed successfully\n");

    // Show sample of updated projects
    const samples = await projectsCollection.find({}).limit(3).toArray();
    console.log("Sample projects after migration:");
    samples.forEach((project, index) => {
      console.log(`\n${index + 1}. ${project.project_name}`);
      console.log(`   isReviewApplicable: ${project.isReviewApplicable}`);
    });

    await mongoose.disconnect();
    console.log("\n✓ Disconnected from MongoDB");
    process.exit(0);
  } catch (error) {
    console.error("❌ Migration error:", error);
    process.exit(1);
  }
}

migrateIsReviewApplicable();
