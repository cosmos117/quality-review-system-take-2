import ProjectMembership from '../models/projectMembership.models.js';
import Project from '../models/project.models.js';
import { User } from '../models/user.models.js';
import { Role } from '../models/roles.models.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { ApiResponse } from '../utils/ApiResponse.js';

// GET /api/v1/projects/members - Get project members
export const getProjectMembers = asyncHandler(async (req, res) => {
    const project_id = req.query.project_id || req.body?.project_id;
    
    if (!project_id) {
        throw new ApiError(400, 'project_id is required');
    }

    const project = await Project.findById(project_id);
    if (!project) {
        throw new ApiError(404, 'Project not found');
    }

    const members = await ProjectMembership.find({ project_id })
        .populate('user_id', 'name email')
        .populate('role_id', 'name')
        .lean();

    return res.status(200).json(
        new ApiResponse(200, {
            project: project.title,
            members
        }, 'Members fetched successfully')
    );
});

// POST /api/v1/projects/members - Add member to project
export const addProjectMember = asyncHandler(async (req, res) => {
    const { project_id, user_id, role_id } = req.body;
    
    if (!project_id || !user_id || !role_id) {
        throw new ApiError(400, 'project_id, user_id, and role_id are required');
    }

    const membership = await ProjectMembership.create({
        project_id,
        user_id,
        role_id
    });

    return res.status(201).json(
        new ApiResponse(201, membership, 'Member added to project successfully')
    );
});

// PUT /api/v1/projects/members - Update member role
export const updateProjectMember = asyncHandler(async (req, res) => {
    const { project_id, user_id, role_id } = req.body;
    
    if (!project_id || !user_id || !role_id) {
        throw new ApiError(400, 'project_id, user_id, and role_id are required');
    }

    const membership = await ProjectMembership.findOneAndUpdate(
        { project_id, user_id },
        { role_id },
        { new: true, runValidators: true }
    ).populate('role_id');

    if (!membership) {
        throw new ApiError(404, 'Project membership not found');
    }

    return res.status(200).json(
        new ApiResponse(200, membership, 'Member role updated successfully')
    );
});

// DELETE /api/v1/projects/members - Remove member from project
export const removeProjectMember = asyncHandler(async (req, res) => {
    const { project_id, user_id } = req.body;
    
    if (!project_id || !user_id) {
        throw new ApiError(400, 'project_id and user_id are required');
    }

    const membership = await ProjectMembership.findOneAndDelete({
        project_id,
        user_id
    });

    if (!membership) {
        throw new ApiError(404, 'Project membership not found');
    }

    return res.status(200).json(
        new ApiResponse(200, null, 'Member removed from project successfully')
    );
});

// GET /api/v1/users/:id/projects - Get all projects for a user
export const getUserProjects = asyncHandler(async (req, res) => {
    const { id } = req.params;

    const projects = await ProjectMembership.find({ user_id: id })
        .populate('project_id')
        .populate('role_id')
        .lean();

    return res.status(200).json(
        new ApiResponse(200, projects, 'User projects fetched successfully')
    );
});