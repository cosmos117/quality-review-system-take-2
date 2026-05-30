import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";
import helmet from "helmet";
import path from "path";
import { fileURLToPath } from "url";
import authMiddleware from "./middleware/auth.Middleware.js";
import requestLogger from "./middleware/requestLogger.js";
import connectDB, { isDatabaseReady } from "./config/db.js";
import logger from "./utils/logger.js";

const app = express();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadsRoot = path.join(__dirname, "..", "uploads");

const rawAllowedOrigins = process.env.FRONTEND_URL || "";
const allowedOrigins = rawAllowedOrigins
  .split(",")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

const corsOriginFn = (origin, callback) => {
  // Allow requests with no origin (mobile apps, Postman, etc.)
  if (!origin) return callback(null, true);

  // Allow localhost and private LAN ranges
  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(
    origin,
  );
  const isLAN =
    /^https?:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin) || // 192.168.x.x
    /^https?:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin) || // 10.x.x.x
    /^https?:\/\/172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(
      origin,
    ); // 172.16-31.x.x

  if (isLocalhost || isLAN) return callback(null, true);

  // Allow if specific FRONTEND_URL origins are configured
  if (allowedOrigins.length > 0) {
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(
      new Error(`CORS: Origin ${origin} not allowed by FRONTEND_URL`),
    );
  }

  // Default: allow all (useful during local dev)
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

// Public URL for uploaded checklist images.
app.use("/uploads", express.static(uploadsRoot));

app.use(requestLogger);

app.use(async (req, res, next) => {
  if (!req.path.startsWith("/api/")) {
    return next();
  }

  if (isDatabaseReady()) {
    return next();
  }

  // Attempt dynamic reconnection if database is not marked ready
  const reconnected = await connectDB();
  if (reconnected) {
    return next();
  }

  return res.status(503).json({
    statusCode: 503,
    message:
      "Database connection is unavailable. Start MySQL or update DATABASE_URL, then retry.",
    success: false,
    data: null,
  });
});

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    uptime: process.uptime(),
    databaseReady: isDatabaseReady(),
  });
});

app.get("/", (req, res) => {
  res.send("<h1>Backend is UP and Running!</h1>");
});

import userRouter from "./routes/user.routes.js";
import roleRoutes from "./routes/role.routes.js";
import projectMembershipRoutes from "./routes/projectMembership.routes.js";
import projectRoutes from "./routes/project.routes.js";
import checklistAnswerRoutes from "./routes/checklistAnswer.routes.js";
import stageRouter from "./routes/stage.routes.js";
import approvalRoutes from "./routes/approval.routes.js";
import projectChecklistRoutes from "./routes/projectChecklist.routes.js";
import templateRoutes from "./routes/template.routes.js";
import templateMultiRoutes from "./routes/template.multi.routes.js";
import analyticsRoutes from "./routes/analytics.routes.js";
import exportRoutes from "./routes/export.routes.js";
import imagesRouter from "./routes/images.js";
import defectCategoryRoutes from "./routes/defect_category_routes.js";

app.use("/api/v1/users", userRouter);
app.use("/api/v1/roles", roleRoutes);

app.use("/api/v1/projects", authMiddleware, projectMembershipRoutes);
app.use("/api/v1/projects", authMiddleware, projectRoutes);
app.use("/api/v1", authMiddleware, checklistAnswerRoutes);
app.use("/api/v1", authMiddleware, stageRouter);
app.use("/api/v1", authMiddleware, approvalRoutes);
app.use("/api/v1", authMiddleware, projectChecklistRoutes);
app.use("/api/v1/templates", authMiddleware, templateRoutes);
app.use("/api/v1/template-library", authMiddleware, templateMultiRoutes);
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
