import dotenv from "dotenv";
import {app} from "./app.js";
import connectDB from "./config/db.js";
import { seedRoles } from "./utils/seedRoles.js";
dotenv.config({
    path:'./.env'
})


connectDB()
.then(()=>{
    app.listen(8000,()=>{
        console.log(`✅ Server is running on port 8000`)
    })
})
.catch((err)=>{
    console.error(`❌ Database connection failed:`, err)
})
