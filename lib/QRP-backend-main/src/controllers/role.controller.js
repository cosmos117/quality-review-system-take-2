import { Role } from '../models/roles.models.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { ApiResponse } from '../utils/ApiResponse.js';

const getAllRoles = asyncHandler(async (req, res) => {
  const roles = await Role.find();
  return res.status(200).json(new ApiResponse(200, roles, 'Roles fetched successfully'));
});

const getRoleById = asyncHandler(async (req, res) => {
  const role = await Role.findById(req.params.id);
  if (!role) {
    throw new ApiError(404, 'Role not found');
  }
  return res.status(200).json(new ApiResponse(200, role, 'Role fetched successfully'));
});

const createRole = asyncHandler(async (req, res) => {
  const { name, description } = req.body;
  if (!name) {
    throw new ApiError(400, 'Role name is required');
  }
  
  const role = await Role.create({ name, description });
  return res.status(201).json(new ApiResponse(201, role, 'Role created successfully'));
});

const updateRole = asyncHandler(async (req, res) => {
  const { name, description } = req.body;
  const role = await Role.findByIdAndUpdate(
    req.params.id,
    { name, description },
    { new: true, runValidators: true }
  );
  
  if (!role) {
    throw new ApiError(404, 'Role not found');
  }
  
  return res.status(200).json(new ApiResponse(200, role, 'Role updated successfully'));
});

const deleteRole = asyncHandler(async (req, res) => {
  const role = await Role.findByIdAndDelete(req.params.id);
  if (!role) {
    throw new ApiError(404, 'Role not found');
  }
  
  return res.status(200).json(new ApiResponse(200, null, 'Role deleted successfully'));
});

export { getAllRoles, getRoleById, createRole, updateRole, deleteRole };