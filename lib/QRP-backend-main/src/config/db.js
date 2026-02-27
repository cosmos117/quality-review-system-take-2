import mongoose from "mongoose";
import { seedRoles } from "../utils/seedRoles.js";
import { fixRoleIndexes } from "../utils/fixRoleIndexes.js";
import dotenv from "dotenv";
dotenv.config({
    path:'./.env'
})
const connectDB=async ()=>{
    try{
        
        // Keep the original URI format to preserve backward compatibility.
        // All existing data (users, checklists, etc.) is in the database
        // that this URI resolves to. GridFS now shares Mongoose's connection
        // (see gridfs.js), so both always use the same database.
        const connectionInstance=await mongoose.connect(`${process.env.MONGO_DB_URI}/${process.env.DB_NAME}`)
        console.log(`✅ MongoDB connected: ${connectionInstance.connection.host} (db: ${connectionInstance.connection.name})`);
        
        // One-time fix: clean up old SDH roles and rebuild with TeamLeader
        // Comment this out after first successful run
        await fixRoleIndexes();
    }
    catch(error){
        console.error("❌ MongoDB connection error:", error);
        process.exit(1)
    }
}

export default connectDB