import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import * as defectService from "../services/defect-category.service.js";

/**
 * Get all global defect categories and groups
 * GET /api/v1/defect-categories
 */
export const getGlobalCategories = asyncHandler(async (req, res) => {
  // Single call that fetches categories + settings in parallel with in-memory caching
  const { categories, settings } = await defectService.getGlobalDefectData();
  
  return res.status(200).json(
    new ApiResponse(200, {
      categories,
      groups: settings.defectCategoryGroups
    }, "Global defect categories fetched successfully")
  );
});

/**
 * Update global defect categories and groups
 * PATCH /api/v1/defect-categories
 * Body: { categories, groups }
 */
export const updateGlobalCategories = asyncHandler(async (req, res) => {
  const { categories, groups } = req.body;
  
  const result = await defectService.updateGlobalDefectCategories(categories, groups);
  // Invalidate the server-side cache so next GET returns fresh data
  defectService.invalidateCache?.();
  
  return res.status(200).json(
    new ApiResponse(200, result, "Global defect categories updated successfully")
  );
});
