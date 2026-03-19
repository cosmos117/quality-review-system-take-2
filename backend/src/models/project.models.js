import mongoose from "mongoose";

const projectSchema = new mongoose.Schema(
  {
    project_no: {
      type: String,
      trim: true,
    },
    internal_order_no: {
      type: String,
      trim: true,
    },
    project_name: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ["pending", "in_progress", "completed"],
      default: "pending",
      required: true,
    },
    priority: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "medium",
    },
    start_date: {
      type: Date,
      required: true,
    },
    end_date: {
      type: Date,
    },
    // Optional named checklist template for this project.
    // If null, the legacy default template is used.
    templateName: {
      type: String,
      trim: true,
      default: null,
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    isReviewApplicable: {
      type: String,
      enum: ["yes", "no", null],
      default: null,
      trim: true,
    },
    reviewApplicableRemark: {
      type: String,
      trim: true,
      default: null,
    },
    overallDefectRate: {
      type: Number,
      default: null,
      min: 0,
    },
  },
  {
    timestamps: true, // adds createdAt and updatedAt automatically
  },
);

projectSchema.index({ created_by: 1 });
projectSchema.index({ status: 1 });

export default mongoose.model("Project", projectSchema);
