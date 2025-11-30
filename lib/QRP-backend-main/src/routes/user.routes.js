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

router.get("/", getAllUsers);                         // GET /api/v1/users
router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/logout", authMiddleware, logoutUser);
router.put("/:id", updateUser);                       // PUT /api/v1/users/:id
router.delete("/:id", deleteUser);                    // DELETE /api/v1/users/:id

// User projects route
router.get("/:id/projects", getUserProjects);


export default router;
