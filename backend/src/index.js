import dotenv from "dotenv";
dotenv.config();

// EXIT HANDLERS (for logging crashes in Render)
process.on("uncaughtException", (err) => {
  console.error("UNCAUGHT EXCEPTION!  Shutting down...");
  console.error(err.name, err.message, err.stack);
  process.exit(1);
});

process.on("unhandledRejection", (err) => {
  console.error("UNHANDLED REJECTION!  Shutting down...");
  console.error(err.name, err.message);
  process.exit(1);
});

import { app } from "./app.js";
import connectDB from "./config/db.js";
import logger from "./utils/logger.js";

const PORT = process.env.PORT || 8000;
// Listen on configured host (defaults to all interfaces).
const HOST = process.env.HOST || "0.0.0.0";

connectDB()
  .then(() => {
    app.listen(PORT, HOST, () => {
      logger.info(`Server is running on http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    logger.error("MySQL connection failed:", err);
    process.exit(1);
  });
