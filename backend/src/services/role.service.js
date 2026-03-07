import { Role } from "../models/roles.models.js";
import { ApiError } from "../utils/ApiError.js";
import { getOrSet, keys, TTL, invalidateRoles } from "../utils/cache.js";

export async function getAllRoles() {
  return getOrSet(keys.allRoles(), async () => {
    return Role.find({}).sort({ role_name: 1 }).lean();
  }, TTL.ROLES);
}

export async function getRoleById(id) {
  return getOrSet(keys.roleById(id), async () => {
    const role = await Role.findById(id).lean();
    if (!role) throw new ApiError(404, "Role not found");
    return role;
  }, TTL.ROLES);
}

export async function createRole({ role_name, description }) {
  const role = await Role.create({ role_name, description });
  invalidateRoles();
  return role;
}

export async function updateRole(id, { role_name, description }) {
  const role = await Role.findByIdAndUpdate(id, { role_name, description }, { new: true }).lean();
  if (!role) throw new ApiError(404, "Role not found");
  invalidateRoles();
  return role;
}

export async function deleteRole(id) {
  const role = await Role.findByIdAndDelete(id);
  if (!role) throw new ApiError(404, "Role not found");
  invalidateRoles();
}
