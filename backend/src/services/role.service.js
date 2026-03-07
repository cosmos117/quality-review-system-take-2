import { Role } from "../models/roles.models.js";
import { ApiError } from "../utils/ApiError.js";

export async function getAllRoles() {
  return Role.find({}).sort({ role_name: 1 }).lean();
}

export async function getRoleById(id) {
  const role = await Role.findById(id).lean();
  if (!role) throw new ApiError(404, "Role not found");
  return role;
}

export async function createRole({ role_name, description }) {
  return Role.create({ role_name, description });
}

export async function updateRole(id, { role_name, description }) {
  const role = await Role.findByIdAndUpdate(id, { role_name, description }, { new: true });
  if (!role) throw new ApiError(404, "Role not found");
  return role;
}

export async function deleteRole(id) {
  const role = await Role.findByIdAndDelete(id);
  if (!role) throw new ApiError(404, "Role not found");
}
