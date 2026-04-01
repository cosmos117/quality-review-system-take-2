import { randomBytes } from "crypto";

/**
 * Generates a 24-character hex ID compatible with MongoDB ObjectId format.
 * Used since Prisma schema uses CHAR(24) for all primary keys.
 */
export function newId() {
  return randomBytes(12).toString("hex");
}
