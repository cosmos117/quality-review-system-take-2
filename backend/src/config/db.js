import mongoose from "mongoose";
import logger from "../utils/logger.js";

const connectDB=async ()=>{
    try{
        const mongoUri = process.env.MONGODB_URI;
        if (!mongoUri) {
            throw new Error("MONGODB_URI is not defined in environment variables");
        }

        const connectionInstance=await mongoose.connect(mongoUri)
        logger.info(`MongoDB connected: ${connectionInstance.connection.host} (db: ${connectionInstance.connection.name})`);
    }
    catch(error){
        logger.error("MongoDB connection error:", error);
        process.exit(1)
    }
}

export default connectDB