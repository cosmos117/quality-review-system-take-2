import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as userService from "../services/user.service.js";

const isProduction = process.env.NODE_ENV === "production";

const cookieOptions = {
  httpOnly: true,
  secure: isProduction,
  sameSite: isProduction ? "strict" : "lax",
};

const registerUser = asyncHandler(async (req, res) => {
  const { name, email, password, role } = req.body;

  if ([name, email, password].some((f) => !f?.trim())) {
    throw new ApiError(400, "All fields are required");
  }

  const validRoles = ["user", "admin"];
  const userRole = role || "user";
  if (!validRoles.includes(userRole)) {
    throw new ApiError(400, "Role must be either 'user' or 'admin'");
  }

  const createdUser = await userService.registerUser({ name, email, password, role: userRole });

  return res
    .status(201)
    .json(new ApiResponse(201, createdUser, "User registered successfully"));
});

const loginUser = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    throw new ApiError(400, "Email and password are required");
  }

  const response = await userService.loginUser({ email, password });

  return res
    .status(200)
    .cookie("token", response.token, cookieOptions)
    .json(new ApiResponse(200, response, "User logged in successfully"));
});

const logoutUser = asyncHandler(async (req, res) => {
  const userId = req.user?._id;
  if (!userId) throw new ApiError(401, "Unauthorized");

  await userService.logoutUser(userId);

  return res
    .status(200)
    .clearCookie("token", cookieOptions)
    .json(new ApiResponse(200, {}, "User logged out successfully"));
});

const getAllUsers = async (req, res) => {
  try {
    const result = await userService.getAllUsers(req.query);
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const updateUser = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    if (role && !["user", "admin"].includes(role)) {
      return res.status(400).json({ success: false, message: 'Role must be either "user" or "admin"' });
    }

    const updatedUser = await userService.updateUser(req.params.id, { name, email, password, role });

    res.status(200).json({ success: true, data: updatedUser, message: "User updated successfully" });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};

const deleteUser = async (req, res) => {
  try {
    const result = await userService.deleteUser(req.params.id);

    res.status(200).json({ success: true, message: "User deleted successfully", deletedMemberships: result.deletedMemberships });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};

export { registerUser, loginUser, logoutUser, getAllUsers, updateUser, deleteUser };


