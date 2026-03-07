import * as membershipService from "../services/projectMembership.service.js";

// GET /api/v1/projects/members - Get project members
export const getProjectMembers = async (req, res) => {
    try {
        const project_id = req.method === 'GET'
            ? (req.query.project_id || req.body?.project_id)
            : (req.body.project_id || req.query?.project_id);
        
        if (!project_id) {
            return res.status(400).json({ success: false, message: 'project_id is required' });
        }

        const result = await membershipService.getProjectMembers(project_id, req.query);
        if (result.error) {
            return res.status(result.error).json({ success: false, message: result.message });
        }

        res.status(200).json({
            ...result.pagination,
            data: { project: result.project, members: result.members }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// POST /api/v1/projects/members - Add member to project
export const addProjectMember = async (req, res) => {
    try {
        const { project_id, user_id, role_id } = req.body;

        const result = await membershipService.addProjectMember(project_id, user_id, role_id);
        if (result?.error) {
            return res.status(result.error).json({ success: false, message: result.message });
        }

        res.status(201).json({ success: true, data: result });
    } catch (error) {
        if (error.code === 11000) {
            return res.status(409).json({ success: false, message: 'User already has this role in the project' });
        }
        res.status(500).json({ success: false, message: error.message });
    }
};

// PUT /api/v1/projects/members - Update member role
export const updateProjectMember = async (req, res) => {
    try {
        const { project_id, user_id, role_id } = req.body;

        const result = await membershipService.updateProjectMember(project_id, user_id, role_id);
        if (result?.error) {
            return res.status(result.error).json({ success: false, message: result.message });
        }

        res.status(200).json({ success: true, data: result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// DELETE /api/v1/projects/members - Remove member from project
export const removeProjectMember = async (req, res) => {
    try {
        const { project_id, user_id } = req.body;

        const result = await membershipService.removeProjectMember(project_id, user_id);
        if (result?.error) {
            return res.status(result.error).json({ success: false, message: result.message });
        }

        res.status(200).json({ success: true, message: 'Member removed from project successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// GET /api/v1/users/:id/projects - Get all projects for a user
export const getUserProjects = async (req, res) => {
    try {
        const { id } = req.params;

        const result = await membershipService.getUserProjects(id);
        if (result?.error) {
            return res.status(result.error).json({ success: false, message: result.message });
        }

        res.status(200).json({ success: true, data: result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};