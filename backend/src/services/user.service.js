import { User } from "../models/user.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import { ApiError } from "../utils/ApiError.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";
import { clearAnalyticsCache } from "./analytics-excel.service.js";

export async function registerUser({ name, email, password, role }) {
  const existingUser = await User.findOne({ email }).select("_id").lean();
  if (existingUser) {
    throw new ApiError(409, "User already exists with this email");
  }

  const user = await User.create({ name, email, password, role });

  const createdUser = await User.findById(user._id)
    .select("-password -accessToken")
    .lean();

  if (!createdUser) {
    throw new ApiError(500, "Something went wrong while registering user");
  }

  return createdUser;
}

export async function loginUser({ email, password }) {
  const user = await User.findOne({ email });
  if (!user) throw new ApiError(404, "User not found");

  const isPasswordValid = await user.isPasswordCorrect(password);
  if (!isPasswordValid) throw new ApiError(404, "Invalid credentials");

  const accessToken = user.generateAccessToken();
  user.accessToken = accessToken;
  await user.save();

  const loggedUser = await User.findById(user._id)
    .select("-password -accessToken")
    .lean();

  return { ...loggedUser, token: accessToken };
}

export async function logoutUser(userId) {
  await User.findByIdAndUpdate(userId, { accessToken: null });
}

export async function getAllUsers(query) {
  const { page, limit, skip } = parsePagination(query);
  const filter = {};
  const total = await User.countDocuments(filter);

  let q = User.find(filter)
    .select("-password -accessToken")
    .sort({ createdAt: -1 })
    .lean();

  if (limit) q = q.skip(skip).limit(limit);

  const users = await q;
  return paginatedResponse(users, total, { page, limit });
}

export async function updateUser(userId, { name, email, password, role }) {
  const user = await User.findById(userId);
  if (!user) throw new ApiError(404, "User not found");

  if (email && email !== user.email) {
    const existingUser = await User.findOne({ email }).select("_id").lean();
    if (existingUser) throw new ApiError(409, "Email already in use");
  }

  if (name) user.name = name;
  if (email) user.email = email;
  if (role) user.role = role;
  if (password) user.password = password;

  await user.save();

  return User.findById(user._id).select("-password -accessToken").lean();
}

export async function deleteUser(userId) {
  const user = await User.findByIdAndDelete(userId);
  if (!user) throw new ApiError(404, "User not found");

  const deletedMemberships = await ProjectMembership.deleteMany({
    user_id: userId,
  });
  clearAnalyticsCache();
  return { deletedMemberships: deletedMemberships.deletedCount };
}
