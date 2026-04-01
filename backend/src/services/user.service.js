import prisma from "../config/prisma.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { ApiError } from "../utils/ApiError.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";
import { newId } from "../utils/newId.js";
import { clearAnalyticsCache } from "./analytics-excel.service.js";

export async function registerUser({ name, email, password, role }) {
  const existingUser = await prisma.user.findUnique({
    where: { email },
    select: { id: true },
  });
  if (existingUser) {
    throw new ApiError(409, "User already exists with this email");
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  const user = await prisma.user.create({
    data: {
      id: newId(),
      name,
      email: email.toLowerCase().trim(),
      password: hashedPassword,
      role,
    },
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      status: true,
      createdAt: true,
      updatedAt: true,
    },
  });

  return user;
}

export async function loginUser({ email, password }) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) throw new ApiError(404, "User not found");

  const isPasswordValid = await bcrypt.compare(password, user.password);
  if (!isPasswordValid) throw new ApiError(404, "Invalid credentials");

  const accessToken = jwt.sign(
    { _id: user.id, email: user.email, role: user.role, name: user.name },
    process.env.ACCESS_TOKEN_SECRET,
    { expiresIn: process.env.ACCESS_TOKEN_EXPIRY || "7d" }
  );

  await prisma.user.update({
    where: { id: user.id },
    data: { accessToken },
  });

  const { password: _pw, accessToken: _at, ...loggedUser } = user;
  return { ...loggedUser, token: accessToken };
}

export async function logoutUser(userId) {
  await prisma.user.update({
    where: { id: userId },
    data: { accessToken: null },
  });
}

export async function getAllUsers(query) {
  const { page, limit, skip } = parsePagination(query);
  const total = await prisma.user.count();

  const users = await prisma.user.findMany({
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      status: true,
      createdAt: true,
      updatedAt: true,
    },
    orderBy: { createdAt: "desc" },
    ...(limit ? { skip, take: limit } : {}),
  });

  return paginatedResponse(users, total, { page, limit });
}

export async function updateUser(userId, { name, email, password, role }) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new ApiError(404, "User not found");

  if (email && email !== user.email) {
    const existingUser = await prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    if (existingUser) throw new ApiError(409, "Email already in use");
  }

  const data = {};
  if (name) data.name = name;
  if (email) data.email = email;
  if (role) data.role = role;
  if (password) data.password = await bcrypt.hash(password, 10);

  return prisma.user.update({
    where: { id: userId },
    data,
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      status: true,
      createdAt: true,
      updatedAt: true,
    },
  });
}

export async function deleteUser(userId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true },
  });
  if (!user) throw new ApiError(404, "User not found");

  const { count: deletedMemberships } = await prisma.projectMembership.deleteMany({
    where: { user_id: userId },
  });

  await prisma.user.delete({ where: { id: userId } });

  clearAnalyticsCache();
  return { deletedMemberships };
}
