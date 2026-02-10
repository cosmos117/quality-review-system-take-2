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
        
    })
})
.catch((err)=>{
    
})
