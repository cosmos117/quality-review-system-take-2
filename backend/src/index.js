import dotenv from "dotenv";
dotenv.config();

import {app} from "./app.js";
import connectDB from "./config/db.js";
import logger from "./utils/logger.js";

const PORT = process.env.PORT || 8000;

connectDB()
.then(()=>{
    app.listen(PORT,()=>{
        logger.info(`Server is running on port ${PORT}`);
    })
})
.catch((err)=>{
    logger.error("MongoDB connection failed:", err);
    process.exit(1);
})
