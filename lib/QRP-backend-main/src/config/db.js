import mongoose from "mongoose";
import { seedRoles } from "../utils/seedRoles.js";
import { fixRoleIndexes } from "../utils/fixRoleIndexes.js";
import dotenv from "dotenv";
dotenv.config({
    path:'./.env'
})
const connectDB=async ()=>{
    try{
        
        // Build a valid MongoDB URI: DB name must go BEFORE query params.
        // e.g. mongodb+srv://user:pass@host/mydb?retryWrites=true
        const rawUri = process.env.MONGO_DB_URI;
        const dbName = process.env.DB_NAME;
        let mongoUri;
        if (rawUri.includes('?')) {
            // Insert DB name before the query string
            const [base, query] = rawUri.split('?');
            // Remove trailing slash from base if present, then add /dbName?query
            mongoUri = `${base.replace(/\/+$/, '')}/${dbName}?${query}`;
        } else {
            mongoUri = `${rawUri.replace(/\/+$/, '')}/${dbName}`;
        }

        const connectionInstance=await mongoose.connect(mongoUri)
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