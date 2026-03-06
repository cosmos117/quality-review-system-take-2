import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";
import helmet from "helmet";
import authMiddleware from "./middleware/auth.Middleware.js";

const app = express();

// ── Security headers ──
app.use(helmet());

// ── CORS ──
const corsOrigin = process.env.FRONTEND_URL
  ? process.env.FRONTEND_URL.split(",").map((s) => s.trim())
  : true; // Allow all in development when FRONTEND_URL is not set

app.use(
  cors({
    origin: corsOrigin,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);

// ── Body parsers & cookies ──
app.use(express.json({ limit: "16kb" }));
app.use(express.urlencoded({ extended: true, limit: "16kb" }));
app.use(cookieParser(process.env.COOKIE_SECRET));

// ── Route imports ──
import userRouter from "./routes/user.routes.js";
import roleRoutes from "./routes/role.routes.js";
import projectMembershipRoutes from "./routes/projectMembership.routes.js";
import projectRoutes from "./routes/project.routes.js";
import checklistRoutes from "./routes/checklistRoutes.js";
import checklistAnswerRoutes from "./routes/checklistAnswerRoutes.js";
import stageRouter from "./routes/stage.routes.js";
import approvalRoutes from "./routes/approval.routes.js";
import projectChecklistRoutes from "./routes/projectChecklist.routes.js";
import templateRoutes from "./routes/template.routes.js";
import checkpointRoutes from "./routes/checkpoint.routes.js";
import analyticsRoutes from "./routes/analytics.routes.js";
import exportRoutes from "./routes/export.routes.js";
import imagesRouter from "./routes/images.js";

// ── Public routes (no auth) ──
// Login & register are public inside userRouter; other user routes need auth
app.use("/api/v1/users", userRouter);
// Roles: read-only is public, mutations protected inside the router
app.use("/api/v1/roles", roleRoutes);

// ── Protected routes (auth required on every request) ──
// Mount membership routes BEFORE project routes to avoid ":id" catching "members"
app.use("/api/v1/projects", authMiddleware, projectMembershipRoutes);
app.use("/api/v1/projects", authMiddleware, projectRoutes);
app.use("/api/v1", authMiddleware, checklistRoutes);
app.use("/api/v1", authMiddleware, checklistAnswerRoutes);
app.use("/api/v1", authMiddleware, stageRouter);
app.use("/api/v1", authMiddleware, approvalRoutes);
app.use("/api/v1", authMiddleware, projectChecklistRoutes);
app.use("/api/v1/templates", authMiddleware, templateRoutes);
app.use("/api/v1", authMiddleware, checkpointRoutes);
app.use("/api/v1", authMiddleware, analyticsRoutes);
app.use("/api/v1", authMiddleware, exportRoutes);
app.use("/api/v1", authMiddleware, imagesRouter);

// Global error handler - must be last
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal Server Error";

  res.status(statusCode).json({
    statusCode: statusCode,
    message: message,
    success: false,
    data: null,
  });
});

// 404 handler - must be after all routes
app.use((req, res) => {
  res.status(404).json({
    statusCode: 404,
    message: "Route not found",
    success: false,
    data: null,
  });
});

export { app };
