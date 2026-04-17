/**
 * Parse pagination params from the request query string.
 * When `limit` is omitted (or 0), ALL documents are returned (no cap).
 *
 * @param {object} query   req.query
 * @returns {{ page: number, limit: number|null, skip: number }}
 */
export function parsePagination(query) {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const rawLimit = parseInt(query.limit, 10) || 0;
  const limit = rawLimit > 0 ? rawLimit : null;       // null = no limit
  const skip = limit ? (page - 1) * limit : 0;
  return { page, limit, skip };
}

/**
 * Build the standard paginated response envelope.
 *
 * @param {Array}  data    the documents
 * @param {number} total   total matching documents (from countDocuments)
 * @param {{ page: number, limit: number|null }} pagination  from parsePagination
 */
export function paginatedResponse(data, total, { page, limit }) {
  return {
    success: true,
    data,
    pagination: {
      page,
      limit: limit ?? total,
      total,
      pages: limit ? Math.ceil(total / limit) : 1,
    },
  };
}
