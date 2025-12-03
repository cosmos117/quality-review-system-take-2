import express from 'express';
// auth intentionally omitted per unauthenticated flow
import { compareAnswers, requestApproval, approve, revert, getApprovalStatus } from '../controllers/approval.controller.js';

const router = express.Router();

router.get('/projects/:projectId/approval/compare', compareAnswers);
router.post('/projects/:projectId/approval/request', requestApproval);
router.post('/projects/:projectId/approval/approve', approve);
router.post('/projects/:projectId/approval/revert', revert);
router.get('/projects/:projectId/approval/status', getApprovalStatus);

export default router;
