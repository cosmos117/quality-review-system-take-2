import ProjectMembership from "../models/projectMembership.models.js";
import Project from "../models/project.models.js";
import { User } from "../models/user.models.js";
import { Role } from "../models/roles.models.js";
import { parsePagination, paginatedResponse } from "../utils/paginate.js";

export async function getProjectMembers(projectId, query) {
  const project = await Project.findById(projectId);
  if (!project) return { error: 404, message: "Project not found" };

  const { page, limit, skip } = parsePagination(query);
  const filter = { project_id: projectId };
  const total = await ProjectMembership.countDocuments(filter);

  let q = ProjectMembership.find(filter)
    .populate("user_id", "name email role")
    .populate("role", "role_name description")
    .lean();

  if (limit) q = q.skip(skip).limit(limit);

  const members = await q;

  const validMembers = members.filter(
    (m) => m.user_id && m.user_id._id && m.role && m.role._id
  );

  return {
    pagination: paginatedResponse(validMembers, total, { page, limit }),
    project: project.project_name,
    members: validMembers,
  };
}

export async function addProjectMember(projectId, userId, roleId) {
  const project = await Project.findById(projectId).select("_id").lean();
  if (!project) return { error: 404, message: "Project not found" };

  const user = await User.findById(userId).select("_id").lean();
  if (!user) return { error: 404, message: "User not found" };

  const role = await Role.findById(roleId).select("_id").lean();
  if (!role) return { error: 404, message: "Role not found" };

  const membership = await ProjectMembership.create({
    project_id: projectId,
    user_id: userId,
    role: roleId,
  });

  return ProjectMembership.findById(membership._id)
    .populate("user_id", "name email")
    .populate("role", "role_name description")
    .lean();
}

export async function updateProjectMember(projectId, userId, roleId) {
  const role = await Role.findById(roleId);
  if (!role) return { error: 404, message: "Role not found" };

  const membership = await ProjectMembership.findOneAndUpdate(
    { project_id: projectId, user_id: userId },
    { role: roleId },
    { new: true }
  )
    .populate("user_id", "name email")
    .populate("role", "role_name description");

  if (!membership) return { error: 404, message: "Project membership not found" };
  return membership;
}

export async function removeProjectMember(projectId, userId) {
  const membership = await ProjectMembership.findOneAndDelete({
    project_id: projectId,
    user_id: userId,
  });
  if (!membership) return { error: 404, message: "Project membership not found" };
  return membership;
}

export async function getUserProjects(userId) {
  const user = await User.findById(userId).select("_id name").lean();
  if (!user) return { error: 404, message: "User not found" };

  const projects = await ProjectMembership.find({ user_id: userId })
    .populate("project_id", "project_name status start_date end_date")
    .populate("role", "role_name description")
    .lean();

  return { user: user.name, projects };
}
