import dotenv from "dotenv";
dotenv.config();

// EXIT HANDLERS (for logging crashes in Render)
process.on("uncaughtException", (err) => {
  console.error("UNCAUGHT EXCEPTION! 💥 Shutting down...");
  console.error(err.name, err.message, err.stack);
  process.exit(1);
});

process.on("unhandledRejection", (err) => {
  console.error("UNHANDLED REJECTION! 💥 Shutting down...");
  console.error(err.name, err.message);
  process.exit(1);
});

import {app} from "./app.js";
import connectDB from "./config/db.js";
import logger from "./utils/logger.js";

const PORT = process.env.PORT || 8000;
// Listen on 0.0.0.0 so the server is reachable from ALL network interfaces
// (localhost AND the LAN IP e.g. 192.168.1.45). This is required for LAN sharing.
const HOST = process.env.HOST || "0.0.0.0";

connectDB()
.then(()=>{
    app.listen(PORT, HOST, ()=>{
        logger.info(`Server is running on http://${HOST}:${PORT}`);
        logger.info(`LAN Access: http://<YOUR_LOCAL_IP>:${PORT}`);
        logger.info(`Run 'ipconfig' in CMD to find your Local IPv4 Address`);
    })
})
.catch((err)=>{
    logger.error("MySQL connection failed:", err);
    process.exit(1);
})
