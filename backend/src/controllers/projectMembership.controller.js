import ProjectMembership from '../models/projectMembership.models.js';
import Project from '../models/project.models.js';
import { User } from '../models/user.models.js';
import { Role } from '../models/roles.models.js';
import { parsePagination, paginatedResponse } from '../utils/paginate.js';

// GET /api/v1/projects/members - Get project members
export const getProjectMembers = async (req, res) => {
    try {
        // Support both GET (query) and POST (body) callers
        const project_id = req.method === 'GET'
            ? (req.query.project_id || req.body?.project_id)
            : (req.body.project_id || req.query?.project_id);
        
        if (!project_id) {
            return res.status(400).json({
                success: false,
                message: 'project_id is required'
            });
        }
        
        // Check if project exists
        const project = await Project.findById(project_id);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Project not found'
            });
        }

        const { page, limit, skip } = parsePagination(req.query);
        const filter = { project_id: project_id };
        const total = await ProjectMembership.countDocuments(filter);

        let query = ProjectMembership.find(filter)
            .populate('user_id', 'name email role')
            .populate('role', 'role_name description')
            .lean();

        if (limit) query = query.skip(skip).limit(limit);

        const members = await query;

        // Filter out memberships where user_id or role population failed (deleted users/roles)
        const validMembers = members.filter(m => {
            if (!m.user_id || !m.user_id._id) {
                return false;
            }
            if (!m.role || !m.role._id) {
                return false;
            }
            return true;
        });
        
        res.status(200).json({
            ...paginatedResponse(validMembers, total, { page, limit }),
            data: {
                project: project.project_name,
                members: validMembers
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// POST /api/v1/projects/members - Add member to project
export const addProjectMember = async (req, res) => {
    try {
        const { project_id, user_id, role_id } = req.body;

        // Check if project exists
        const project = await Project.findById(project_id).select("_id").lean();
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Project not found'
            });
        }

        // Check if user exists
        const user = await User.findById(user_id).select("_id").lean();
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check if role exists
        const role = await Role.findById(role_id).select("_id").lean();
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }

        const membership = await ProjectMembership.create({
            project_id: project_id,
            user_id: user_id,
            role: role_id
        });

        const populatedMembership = await ProjectMembership.findById(membership._id)
            .populate('user_id', 'name email')
            .populate('role', 'role_name description')
            .lean();

        res.status(201).json({
            success: true,
            data: populatedMembership
        });
    } catch (error) {
        // Handle duplicate key error
        if (error.code === 11000) {
            return res.status(409).json({
                success: false,
                message: 'User already has this role in the project'
            });
        }
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// PUT /api/v1/projects/members - Update member role
export const updateProjectMember = async (req, res) => {
    try {
        const { project_id, user_id, role_id } = req.body;

        // Check if role exists
        const role = await Role.findById(role_id);
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }

        const membership = await ProjectMembership.findOneAndUpdate(
            { project_id: project_id, user_id: user_id },
            { role: role_id },
            { new: true }
        )
        .populate('user_id', 'name email')
        .populate('role', 'role_name description');

        if (!membership) {
            return res.status(404).json({
                success: false,
                message: 'Project membership not found'
            });
        }

        res.status(200).json({
            success: true,
            data: membership
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// DELETE /api/v1/projects/members - Remove member from project
export const removeProjectMember = async (req, res) => {
    try {
        const { project_id, user_id } = req.body;

        const membership = await ProjectMembership.findOneAndDelete({
            project_id: project_id,
            user_id: user_id
        });

        if (!membership) {
            return res.status(404).json({
                success: false,
                message: 'Project membership not found'
            });
        }

        res.status(200).json({
            success: true,
            message: 'Member removed from project successfully'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// GET /api/v1/users/:id/projects - Get all projects for a user
export const getUserProjects = async (req, res) => {
    try {
        const { id } = req.params; // user id

        // Check if user exists
        const user = await User.findById(id).select("_id name").lean();
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const projects = await ProjectMembership.find({ user_id: id })
            .populate('project_id', 'project_name status start_date end_date')
            .populate('role', 'role_name description')
            .lean();

        res.status(200).json({
            success: true,
            data: {
                user: user.name,
                projects: projects
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};