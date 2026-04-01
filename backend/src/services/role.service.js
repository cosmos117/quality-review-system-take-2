import prisma from "../config/prisma.js";
import { ApiError } from "../utils/ApiError.js";
import { getOrSet, keys, TTL, invalidateRoles } from "../utils/cache.js";
import { newId } from "../utils/newId.js";

export async function getAllRoles() {
  return getOrSet(
    keys.allRoles(),
    async () => {
      return prisma.role.findMany({ orderBy: { role_name: "asc" } });
    },
    TTL.ROLES
  );
}

export async function getRoleById(id) {
  return getOrSet(
    keys.roleById(id),
    async () => {
      const role = await prisma.role.findUnique({ where: { id } });
      if (!role) throw new ApiError(404, "Role not found");
      return role;
    },
    TTL.ROLES
  );
}

export async function createRole({ role_name, description }) {
  const role = await prisma.role.create({
    data: { id: newId(), role_name, description },
  });
  invalidateRoles();
  return role;
}

export async function updateRole(id, { role_name, description }) {
  const role = await prisma.role.update({
    where: { id },
    data: { role_name, description },
  });
  if (!role) throw new ApiError(404, "Role not found");
  invalidateRoles();
  return role;
}

export async function deleteRole(id) {
  const role = await prisma.role.findUnique({ where: { id } });
  if (!role) throw new ApiError(404, "Role not found");
  await prisma.role.delete({ where: { id } });
  invalidateRoles();
}
