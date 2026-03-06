import mongoose from "mongoose";

const connectDB=async ()=>{
    try{
        const mongoUri = process.env.MONGODB_URI;
        if (!mongoUri) {
            throw new Error("MONGODB_URI is not defined in environment variables");
        }

        const connectionInstance=await mongoose.connect(mongoUri)
        console.log(`✅ MongoDB connected: ${connectionInstance.connection.host} (db: ${connectionInstance.connection.name})`);
    }
    catch(error){
        console.error("❌ MongoDB connection error:", error);
        process.exit(1)
    }
}

export default connectDB