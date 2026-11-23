import NodeCache from "node-cache";
import logger from "../utils/logger.js";

// Failed login attempts allowed per (IP, email) within the window. Only
// failures count, and a successful login clears the counter, so normal use
// never hits the limit.
const MAX_FAILED_ATTEMPTS = 10;
const WINDOW_SECONDS = 15 * 60;

// Entries expire on their own, so memory stays bounded.
const failures = new NodeCache({ stdTTL: WINDOW_SECONDS, checkperiod: 120 });

const keyFor = (req) => {
  const email = (req.body?.email || "").toString().trim().toLowerCase();
  return `${req.ip}|${email}`;
};

/**
 * Slows down password guessing on POST /users/login. Keyed by client IP and
 * email, so one user mistyping does not lock out others behind the same IP.
 */
export const loginRateLimit = (req, res, next) => {
  const key = keyFor(req);
  const count = failures.get(key) || 0;

  if (count >= MAX_FAILED_ATTEMPTS) {
    const resetAt = failures.getTtl(key);
    const retryAfter = resetAt
      ? Math.max(1, Math.ceil((resetAt - Date.now()) / 1000))
      : WINDOW_SECONDS;
    res.setHeader("Retry-After", retryAfter);
    return res.status(429).json({
      statusCode: 429,
      message: `Too many failed login attempts. Try again in ${Math.ceil(retryAfter / 60)} minute(s).`,
      success: false,
      data: null,
    });
  }

  res.on("finish", () => {
    if (res.statusCode < 400) {
      failures.del(key);
    } else if (res.statusCode !== 429 && res.statusCode < 500) {
      // Keep the original window: don't extend the TTL on each failure.
      // Re-read: parallel attempts may have counted since this one started.
      const next = (failures.get(key) || 0) + 1;
      const ttl = failures.getTtl(key);
      const remaining = ttl ? Math.ceil((ttl - Date.now()) / 1000) : 0;
      failures.set(key, next, remaining > 0 ? remaining : WINDOW_SECONDS);
      if (next === MAX_FAILED_ATTEMPTS) {
        logger.warn(`Login temporarily blocked after repeated failures (ip=${req.ip})`);
      }
    }
  });

  next();
};
