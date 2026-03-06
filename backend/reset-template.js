import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

const templateSchema = new mongoose.Schema(
  {
    name: { type: String, default: "Default Quality Review Template" },
    defectCategories: { type: [Object], default: [] },
    modifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  {
    timestamps: true,
    strict: false,
  },
);

const Template = mongoose.model("Template", templateSchema);

async function resetTemplate() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("MongoDB connected");

    const result = await Template.deleteMany({});
    console.log(`✅ Deleted ${result.deletedCount} template document(s)`);

    await mongoose.disconnect();
    console.log("✅ Database reset complete");
    process.exit(0);
  } catch (error) {
    console.error("❌ Error resetting template:", error.message);
    process.exit(1);
  }
}

resetTemplate();
