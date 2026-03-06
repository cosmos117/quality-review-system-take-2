import { Router } from 'express';
import {
    getAllRoles,
    getRoleById,
    createRole,
    updateRole,
    deleteRole
} from '../controllers/role.controller.js';
import authMiddleware from '../middleware/auth.Middleware.js';

const router = Router();

// Public (needed for login flow role display)
router.get('/', getAllRoles);
router.get('/:id', getRoleById);

// Protected
router.post('/', authMiddleware, createRole);
router.put('/:id', authMiddleware, updateRole);
router.delete('/:id', authMiddleware, deleteRole);

export default router;