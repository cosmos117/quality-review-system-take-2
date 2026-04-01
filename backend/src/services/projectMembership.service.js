import prisma from "../config/prisma.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";

export async function getProjectMembers(projectId, query) {
  const project = await prisma.project.findUnique({
    where: { id: projectId },
    select: { id: true, project_name: true },
  });
  if (!project) return { error: 404, message: "Project not found" };

  const { page, limit, skip } = parsePagination(query);
  
  const total = await prisma.projectMembership.count({
    where: { project_id: projectId },
  });

  const members = await prisma.projectMembership.findMany({
    where: { project_id: projectId },
    include: {
      user: { select: { id: true, name: true, email: true, role: true } },
      role: { select: { id: true, role_name: true, description: true } },
    },
    ...(limit ? { skip, take: limit } : {}),
  });

  // Re-map to match previous Mongoose format
  const formattedMembers = members.map((m) => ({
    ...m,
    user_id: m.user,
    role: m.role,
  }));

  return {
    pagination: paginatedResponse(formattedMembers, total, { page, limit }),
    project: project.project_name,
    members: formattedMembers,
  };
}

export async function addProjectMember(projectId, userId, roleId) {
  const project = await prisma.project.findUnique({ where: { id: projectId } });
  if (!project) return { error: 404, message: "Project not found" };

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { error: 404, message: "User not found" };

  const role = await prisma.role.findUnique({ where: { id: roleId } });
  if (!role) return { error: 404, message: "Role not found" };

  const membership = await prisma.projectMembership.create({
    data: { project_id: projectId, user_id: userId, role_id: roleId },
    include: {
      user: { select: { name: true, email: true } },
      role: { select: { role_name: true, description: true } },
    },
  });

  return { ...membership, user_id: membership.user, role: membership.role };
}

export async function updateProjectMember(projectId, userId, roleId) {
  const role = await prisma.role.findUnique({ where: { id: roleId } });
  if (!role) return { error: 404, message: "Role not found" };

  const existingMembership = await prisma.projectMembership.findFirst({
    where: { project_id: projectId, user_id: userId },
  });

  if (!existingMembership) return { error: 404, message: "Project membership not found" };

  const membership = await prisma.projectMembership.update({
    where: { id: existingMembership.id },
    data: { role_id: roleId },
    include: {
      user: { select: { name: true, email: true } },
      role: { select: { role_name: true, description: true } },
    },
  });

  return { ...membership, user_id: membership.user, role: membership.role };
}

export async function removeProjectMember(projectId, userId) {
  const existingMembership = await prisma.projectMembership.findFirst({
    where: { project_id: projectId, user_id: userId },
  });

  if (!existingMembership) return { error: 404, message: "Project membership not found" };

  const membership = await prisma.projectMembership.delete({
    where: { id: existingMembership.id },
  });

  return membership;
}

export async function getUserProjects(userId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true },
  });
  if (!user) return { error: 404, message: "User not found" };

  const projects = await prisma.projectMembership.findMany({
    where: { user_id: userId },
    include: {
      project: {
        select: {
          id: true,
          project_name: true,
          status: true,
          start_date: true,
          end_date: true,
        },
      },
      role: { select: { id: true, role_name: true, description: true } },
    },
  });

  const formattedProjects = projects.map((m) => ({
    ...m,
    project_id: m.project,
    role: m.role,
  }));

  return { user: user.name, projects: formattedProjects };
}
