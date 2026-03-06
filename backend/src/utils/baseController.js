/**
 * Base Controller Utility
 * Provides reusable methods for common CRUD operations and error handling
 * Reduces code duplication across all controller files
 */

import { ApiError } from "./ApiError.js";
import { ApiResponse } from "./ApiResponse.js";

/**
 * Base CRUD Controller
 * Extends this class and override methods as needed
 */
export class BaseController {
  /**
   * Get a single document by ID
   * @param {Model} Model - Mongoose model
   * @param {String} id - Document ID
   * @param {Object} options - Query options {lean: true, select: undefined, populate: undefined}
   */
  async getById(Model, id, options = {}) {
    const { lean = true, select, populate } = options;
    let query = Model.findById(id);
    if (select) query = query.select(select);
    if (populate) query = query.populate(populate);
    if (lean) query = query.lean();
    return await query;
  }

  /**
   * Get all documents with optional filtering and pagination
   * @param {Model} Model - Mongoose model
   * @param {Object} filters - Query filters
   * @param {Object} options - {page, limit, sort, select, populate, lean}
   */
  async getAll(Model, filters = {}, options = {}) {
    const {
      page = 1,
      limit = 10,
      sort = { created_at: -1 },
      select,
      populate,
      lean = true
    } = options;

    const skip = (page - 1) * limit;
    let query = Model.find(filters);
    
    if (select) query = query.select(select);
    if (populate) query = query.populate(populate);
    if (sort) query = query.sort(sort);
    if (lean) query = query.lean();

    const total = await Model.countDocuments(filters);
    const documents = await query.skip(skip).limit(limit);

    return {
      documents,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    };
  }

  /**
   * Create a new document
   * @param {Model} Model - Mongoose model
   * @param {Object} data - Document data
   */
  async create(Model, data) {
    const document = new Model(data);
    return await document.save();
  }

  /**
   * Update a document by ID
   * @param {Model} Model - Mongoose model
   * @param {String} id - Document ID
   * @param {Object} updates - Update data
   * @param {Object} options - {new: true, runValidators: true}
   */
  async updateById(Model, id, updates, options = {}) {
    const defaultOptions = { new: true, runValidators: true };
    return await Model.findByIdAndUpdate(
      id,
      updates,
      { ...defaultOptions, ...options }
    );
  }

  /**
   * Delete a document by ID
   * @param {Model} Model - Mongoose model
   * @param {String} id - Document ID
   */
  async deleteById(Model, id) {
    return await Model.findByIdAndDelete(id);
  }

  /**
   * Bulk write operations (optimized for multiple operations)
   * @param {Model} Model - Mongoose model
   * @param {Array} operations - Array of bulk write operations
   */
  async bulkWrite(Model, operations) {
    if (!operations || operations.length === 0) {
      return { ok: 1, n: 0 };
    }
    return await Model.bulkWrite(operations);
  }

  /**
   * Bulk delete multiple documents
   * @param {Model} Model - Mongoose model
   * @param {Array} ids - Array of document IDs
   */
  async deleteMany(Model, ids) {
    if (!ids || ids.length === 0) {
      return { deletedCount: 0 };
    }
    return await Model.deleteMany({ _id: { $in: ids } });
  }

  /**
   * Bulk update multiple documents
   * @param {Model} Model - Mongoose model
   * @param {Object} filter - Filter criteria
   * @param {Object} updates - Update data
   */
  async updateMany(Model, filter, updates) {
    return await Model.updateMany(filter, updates);
  }

  /**
   * Count documents matching filter
   * @param {Model} Model - Mongoose model
   * @param {Object} filter - Query filter
   */
  async count(Model, filter = {}) {
    return await Model.countDocuments(filter);
  }

  /**
   * Check if document exists
   * @param {Model} Model - Mongoose model
   * @param {Object} filter - Query filter
   */
  async exists(Model, filter) {
    return await Model.exists(filter);
  }

  /**
   * Find with custom query (for complex queries)
   * @param {Model} Model - Mongoose model
   * @param {Function} queryFn - Function that receives and returns query object
   */
  async find(Model, queryFn) {
    let query = Model.find();
    if (queryFn) query = queryFn(query);
    return await query;
  }
}

/**
 * Standard response handler
 * Sends consistent API responses
 */
export const sendSuccess = (res, statusCode, data, message = "Success") => {
  return res.status(statusCode).json(
    new ApiResponse(statusCode, data, message)
  );
};

/**
 * Standard error handler
 * Sends consistent error responses
 */
export const sendError = (res, statusCode, message) => {
  throw new ApiError(statusCode, message);
};

/**
 * Validation helper
 * Checks required fields and returns error if missing
 */
export const validateRequired = (data, requiredFields) => {
  const missing = requiredFields.filter(field => !data[field]);
  if (missing.length > 0) {
    throw new ApiError(400, `Missing required fields: ${missing.join(", ")}`);
  }
};

/**
 * Authorization helper
 * Checks if user has required role
 */
export const checkRole = (userRole, requiredRoles) => {
  if (!requiredRoles.includes(userRole)) {
    throw new ApiError(403, "You don't have permission to perform this action");
  }
};

/**
 * Pagination calculator
 */
export const calculatePagination = (page, limit, total) => {
  const pageNum = Math.max(1, page || 1);
  const limitNum = Math.max(1, Math.min(limit || 10, 100)); // Max 100 per page
  const skip = (pageNum - 1) * limitNum;
  
  return {
    page: pageNum,
    limit: limitNum,
    skip,
    total,
    pages: Math.ceil(total / limitNum)
  };
};

/**
 * Sort builder
 * Safely builds sort object from string
 */
export const buildSort = (sortString = "-created_at") => {
  const parts = sortString.split(",");
  const sort = {};
  
  parts.forEach(part => {
    const field = part.trim();
    if (field.startsWith("-")) {
      sort[field.slice(1)] = -1;
    } else {
      sort[field] = 1;
    }
  });
  
  return sort;
};

/**
 * Query filter builder
 * Safely builds MongoDB filter from query params
 */
export const buildFilter = (queryParams, allowedFields) => {
  const filter = {};
  
  allowedFields.forEach(field => {
    if (queryParams[field] !== undefined) {
      filter[field] = queryParams[field];
    }
  });
  
  return filter;
};
