import express from "express";
import {
  registerUser,
  loginUser,
  logoutUser,
  getAllUsers,
  updateUser,
  deleteUser
} from "../controllers/user.controller.js";
import { getUserProjects } from "../controllers/projectMembership.controller.js";
import authMiddleware from "../middleware/auth.Middleware.js";
import { requireAdmin } from "../middleware/role.middleware.js";
import { loginRateLimit } from "../middleware/loginRateLimit.js";

const router = express.Router();

// Public routes
router.post("/login", loginRateLimit, loginUser);

// Creating accounts (including admin accounts) is an admin action. The first
// admin comes from seed.js.
router.post("/register", authMiddleware, requireAdmin, registerUser);

// Protected routes
router.get("/", authMiddleware, getAllUsers);
router.post("/logout", authMiddleware, logoutUser);
// Admins can edit anyone; other users only themselves (checked in controller).
router.put("/:id", authMiddleware, updateUser);
router.delete("/:id", authMiddleware, requireAdmin, deleteUser);

// User projects route
router.get("/:id/projects", authMiddleware, getUserProjects);


export default router;
