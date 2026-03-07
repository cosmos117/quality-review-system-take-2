import * as roleService from "../services/role.service.js";

export const getAllRoles = async (req, res) => {
  try {
    const roles = await roleService.getAllRoles();
    res.status(200).json({ success: true, data: roles });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

export const getRoleById = async (req, res) => {
  try {
    const role = await roleService.getRoleById(req.params.id);
    res.status(200).json({ success: true, data: role });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};

export const createRole = async (req, res) => {
  try {
    const { role_name, description } = req.body;
    const role = await roleService.createRole({ role_name, description });
    res.status(201).json({ success: true, data: role });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

export const updateRole = async (req, res) => {
  try {
    const { role_name, description } = req.body;
    const role = await roleService.updateRole(req.params.id, { role_name, description });
    res.status(200).json({ success: true, data: role });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};

export const deleteRole = async (req, res) => {
  try {
    await roleService.deleteRole(req.params.id);
    res.status(200).json({ success: true, message: "Role deleted successfully" });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ success: false, message: error.message });
  }
};