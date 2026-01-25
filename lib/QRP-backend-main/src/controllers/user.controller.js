import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import { User } from "../models/user.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt";

const validRoles = ['admin', 'user'];

const registerUser = asyncHandler(async (req, res) => {
  const { name, email, password, role } = req.body;
  const userRole = role || 'user';

  if (!validRoles.includes(userRole)) {
    throw new ApiError(400, "Role must be either 'user' or 'admin'");
  }

  const existingUser = await User.findOne({ email });
  if (existingUser) {
    throw new ApiError(409, "User with this email already exists");
  }

  const user = await User.create({
    name,
    email,
    password,
    role: userRole,
  });

  const accessToken = user.generateAccessToken();
  user.accessToken = accessToken;
  await user.save();

  const createdUser = await User.findById(user._id).select("-password -accessToken");

  return res
    .status(201)
    .json(new ApiResponse(201, createdUser, "User registered successfully"));
});

const loginUser = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    throw new ApiError(400, "Email and password are required");
  }

  const user = await User.findOne({ email });
  if (!user) {
    throw new ApiError(401, "Invalid email or password");
  }

  const isPasswordValid = await user.isPasswordCorrect(password);
  if (!isPasswordValid) {
    throw new ApiError(401, "Invalid email or password");
  }

  const accessToken = user.generateAccessToken();
  user.accessToken = accessToken;
  await user.save();

  const loggedUser = await User.findById(user._id).select("-password -accessToken");

  const userObj = loggedUser.toObject ? loggedUser.toObject() : loggedUser;
  const response = {
    ...userObj,
    token: accessToken,
  };

  const options = {
    httpOnly: true,
    secure: false,
  };

  return res
    .status(200)
    .cookie("token", accessToken, options)
    .json(new ApiResponse(200, response, "User logged in successfully"));
});

const logoutUser = asyncHandler(async (req, res) => {
  const userId = req.user?._id;

  if (!userId) throw new ApiError(401, "Unauthorized");

  await User.findByIdAndUpdate(userId, { accessToken: null });

  const options = {
    httpOnly: true,
    secure: false,
  };

  return res
    .status(200)
    .clearCookie("token", options)
    .json(new ApiResponse(200, {}, "User logged out successfully"));
});

const getAllUsers = asyncHandler(async (req, res) => {
  const users = await User.find().select("-password -accessToken");

  return res
    .status(200)
    .json(new ApiResponse(200, users, "Users fetched successfully"));
});

const updateUser = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, email, password, role } = req.body;

  const user = await User.findById(id);
  if (!user) {
    throw new ApiError(404, "User not found");
  }

  if (name) user.name = name;
  if (email) user.email = email;
  if (role && validRoles.includes(role)) user.role = role;
  if (password) user.password = password;

  await user.save();

  const updatedUser = await User.findById(user._id).select("-password -accessToken");

  return res
    .status(200)
    .json(new ApiResponse(200, updatedUser, "User updated successfully"));
});

const deleteUser = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const user = await User.findById(id);
  if (!user) {
    throw new ApiError(404, "User not found");
  }

  // Cascade delete: Remove all project memberships associated with this user
  const deletedMemberships = await ProjectMembership.deleteMany({
    user_id: id,
  });

  await User.findByIdAndDelete(id);

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        deletedUser: user,
        deletedMemberships: deletedMemberships.deletedCount,
      },
      "User deleted successfully"
    )
  );
});

export { registerUser, loginUser, logoutUser, getAllUsers, updateUser, deleteUser };


