import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import { requireAdmin } from "../middleware/role.middleware.js";
import * as controller from "../controllers/defect_category_controller.js";

const router = express.Router();

router.get("/", authMiddleware, controller.getGlobalCategories);
router.patch("/", authMiddleware, requireAdmin, controller.updateGlobalCategories);

export default router;
