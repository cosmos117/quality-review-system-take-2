import mongoose from "mongoose";
import dotenv from "dotenv";
import Template from "./src/models/template.models.js";

dotenv.config();
await mongoose.connect(process.env.MONGODB_URI);
const t = await Template.findOne({ templateName: "cfm" }).lean();
if (!t) {
  console.log("template cfm not found");
} else {
  const stageKeys = Object.keys(t).filter(k => /^stage\d{1,2}$/.test(k)).sort((a,b)=>Number(a.replace("stage",""))-Number(b.replace("stage","")));
  console.log("stageKeys", stageKeys);
  console.log("stageNames", t.stageNames || {});
  for (const k of stageKeys) {
    const arr = Array.isArray(t[k]) ? t[k] : [];
    console.log(k, "groups", arr.length);
  }
}
await mongoose.disconnect();
