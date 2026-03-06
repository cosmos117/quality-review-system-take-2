/**
 * Check current isReviewApplicable values in projects
 * Run with: node check-isReviewApplicable.js
 */

import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config({ path: "./.env" });

const MONGODB_URI = process.env.MONGO_DB_URI;
// Check both test and authdb databases
const DB_NAMES = ["test", "authdb"];

async function checkIsReviewApplicable() {
  try {
    for (const DB_NAME of DB_NAMES) {
      await mongoose.connect(MONGODB_URI, { dbName: DB_NAME });
      console.log(`\n========================================`);
      console.log(`✓ Connected to MongoDB`);
      console.log(`✓ Checking database: ${DB_NAME}`);
      console.log(`========================================\n`);

      const db = mongoose.connection.db;
      const projectsCollection = db.collection("projects");

      const totalProjects = await projectsCollection.countDocuments();
      console.log(`Total projects: ${totalProjects}\n`);

      // Count by isReviewApplicable value
      const withNull = await projectsCollection.countDocuments({
        isReviewApplicable: null,
      });
      const withYes = await projectsCollection.countDocuments({
        isReviewApplicable: "yes",
      });
      const withNo = await projectsCollection.countDocuments({
        isReviewApplicable: "no",
      });
      const withTrue = await projectsCollection.countDocuments({
        isReviewApplicable: true,
      });
      const withFalse = await projectsCollection.countDocuments({
        isReviewApplicable: false,
      });
      const withoutField = await projectsCollection.countDocuments({
        isReviewApplicable: { $exists: false },
      });

      console.log("isReviewApplicable statistics:");
      console.log(`  null:     ${withNull}`);
      console.log(`  "yes":    ${withYes}`);
      console.log(`  "no":     ${withNo}`);
      console.log(`  true:     ${withTrue} (legacy boolean)`);
      console.log(`  false:    ${withFalse} (legacy boolean)`);
      console.log(`  missing:  ${withoutField}`);
      console.log();

      // Show sample projects with their isReviewApplicable values
      console.log("Sample projects (showing all fields):");
      const samples = await projectsCollection.find({}).limit(5).toArray();
      samples.forEach((project, index) => {
        console.log(`\n${index + 1}. ${project.project_name}`);
        console.log(`   _id: ${project._id}`);
        console.log(`   project_no: ${project.project_no}`);
        console.log(`   internal_order_no: ${project.internal_order_no}`);
        console.log(`   status: ${project.status}`);
        console.log(
          `   isReviewApplicable: ${JSON.stringify(project.isReviewApplicable)} (type: ${typeof project.isReviewApplicable})`,
        );
      });

      await mongoose.disconnect();
      console.log(`\n✓ Disconnected from database: ${DB_NAME}`);
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

checkIsReviewApplicable();
