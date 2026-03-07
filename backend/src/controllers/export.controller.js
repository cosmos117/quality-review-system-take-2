import { asyncHandler } from "../utils/asyncHandler.js";
import * as exportService from "../services/export.service.js";

/**
 * GET /admin/export/master-excel
 * Generates a comprehensive Excel file with question-level checklist data
 */
export const exportMasterExcel = asyncHandler(async (req, res) => {
  const buffer = await exportService.generateMasterExcel();

  res.setHeader(
    "Content-Type",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  );
  res.setHeader(
    "Content-Disposition",
    `attachment; filename="master_export_${new Date().toISOString().split("T")[0]}_${Date.now()}.xlsx"`,
  );
  res.setHeader("Content-Length", buffer.length);

  res.send(buffer);
});
