import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";
import helmet from "helmet";
import authMiddleware from "./middleware/auth.Middleware.js";
import requestLogger from "./middleware/requestLogger.js";
import logger from "./utils/logger.js";

const app = express();

// app.use(helmet()); // Temporarily disabled to debug Render connection issues

// ── CORS ──
// If FRONTEND_URL is set in .env, only allow those origins (comma-separated).
const rawAllowedOrigins = process.env.FRONTEND_URL || "";
const allowedOrigins = rawAllowedOrigins
  .split(",")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

const corsOriginFn = (origin, callback) => {
  // Allow requests with no origin (REST clients, mobile apps, Postman)
  if (!origin) return callback(null, true);

  // 1. Always allow localhost and private LAN subnets
  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const isLAN =
    /^https?:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin) || // 192.168.x.x
    /^https?:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin) || // 10.x.x.x
    /^https?:\/\/172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin); // 172.16-31.x.x

  if (isLocalhost || isLAN) return callback(null, true);

  // 2. Allow if specific FRONTEND_URL origins are set
  if (allowedOrigins.length > 0) {
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error(`CORS: Origin ${origin} not allowed by FRONTEND_URL`));
  }

  // 3. Fallback: Allow all origins during development/setup
  return callback(null, true);
};


app.use(
  cors({
    origin: corsOriginFn,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);

app.use(express.json({ limit: "16kb" }));
app.use(express.urlencoded({ extended: true, limit: "16kb" }));
app.use(cookieParser(process.env.COOKIE_SECRET));

app.use(requestLogger);

app.get("/health", (req, res) => {
  res.json({ status: "ok", uptime: process.uptime() });
});

app.get("/", (req, res) => {
  res.send("<h1>Backend is UP and Running!</h1>");
});

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
import templateMultiRoutes from "./routes/template.multi.routes.js";
import checkpointRoutes from "./routes/checkpoint.routes.js";
import analyticsRoutes from "./routes/analytics.routes.js";
import exportRoutes from "./routes/export.routes.js";
import imagesRouter from "./routes/images.js";
import defectCategoryRoutes from "./routes/defect_category_routes.js";


app.use("/api/v1/users", userRouter);
app.use("/api/v1/roles", roleRoutes);

app.use("/api/v1/projects", authMiddleware, projectMembershipRoutes);
app.use("/api/v1/projects", authMiddleware, projectRoutes);
app.use("/api/v1", authMiddleware, checklistRoutes);
app.use("/api/v1", authMiddleware, checklistAnswerRoutes);
app.use("/api/v1", authMiddleware, stageRouter);
app.use("/api/v1", authMiddleware, approvalRoutes);
app.use("/api/v1", authMiddleware, projectChecklistRoutes);
app.use("/api/v1/templates", authMiddleware, templateRoutes);
app.use("/api/v1/template-library", authMiddleware, templateMultiRoutes);
app.use("/api/v1", authMiddleware, checkpointRoutes);
app.use("/api/v1", authMiddleware, analyticsRoutes);
app.use("/api/v1", authMiddleware, exportRoutes);
app.use("/api/v1/", authMiddleware, imagesRouter);
app.use("/api/v1/defect-categories", authMiddleware, defectCategoryRoutes);


app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal Server Error";

  if (statusCode >= 500) {
    logger.error(`${req.method} ${req.originalUrl} - ${message}`, {
      stack: err.stack,
    });
  }

  res.status(statusCode).json({
    statusCode: statusCode,
    message: message,
    success: false,
    data: null,
  });
});

app.use((req, res) => {
  res.status(404).json({
    statusCode: 404,
    message: "Route not found",
    success: false,
    data: null,
  });
});

export { app };
