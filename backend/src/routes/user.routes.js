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

const router = express.Router();

// Public routes
router.post("/register", registerUser);
router.post("/login", loginUser);

// Protected routes
router.get("/", authMiddleware, getAllUsers);
router.post("/logout", authMiddleware, logoutUser);
router.put("/:id", authMiddleware, updateUser);
router.delete("/:id", authMiddleware, deleteUser);

// User projects route
router.get("/:id/projects", authMiddleware, getUserProjects);


export default router;
