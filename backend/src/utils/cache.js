import NodeCache from "node-cache";

// TTL values in seconds
const TTL = {
  PROJECTS: 30,       // 30s  project list changes moderately often
  PROJECT_BY_ID: 60,  // 1min  individual project detail
  PROJECT_STAGES: 60, // 1min  stages for a project
  TEMPLATES: 120,     // 2min  template rarely changes
  ROLES: 120,         // 2min  roles are near-static
  STAGES: 60,         // 1min  stage data
};

// Single shared cache instance with check-period of 30s
const cache = new NodeCache({ stdTTL: 60, checkperiod: 30 });

// Cache key builders 

const keys = {
  allProjects: (queryStr) => `projects:all:${queryStr || "default"}`,
  userProjects: (userId) => `projects:user:${userId}`,
  projectById: (id) => `projects:id:${id}`,
  projectStages: (projectId) => `projects:stages:${projectId}`,
  template: (stage) => `template:${stage || "full"}`,
  allRoles: () => "roles:all",
  roleById: (id) => `roles:id:${id}`,
  stagesForProject: (projectId) => `stages:project:${projectId}`,
  stageById: (id) => `stages:id:${id}`,
};

// Cache helpers 

/**
 * Get-or-set pattern: returns cached value if present, otherwise calls
 * `fetchFn`, caches the result, and returns it.
 */
async function getOrSet(key, fetchFn, ttl) {
  const cached = cache.get(key);
  if (cached !== undefined) return cached;

  const data = await fetchFn();
  if (data !== undefined && data !== null) {
    cache.set(key, data, ttl);
  }
  return data;
}

/**
 * Invalidate all keys matching a prefix (e.g. "projects:" clears all project caches).
 */
function invalidateByPrefix(prefix) {
  const allKeys = cache.keys();
  const toDelete = allKeys.filter((k) => k.startsWith(prefix));
  if (toDelete.length > 0) cache.del(toDelete);
}

// Domain-level invalidation 

function invalidateProjects() {
  invalidateByPrefix("projects:");
}

function invalidateTemplate() {
  invalidateByPrefix("template:");
}

function invalidateRoles() {
  invalidateByPrefix("roles:");
}

function invalidateStages(projectId) {
  if (projectId) {
    cache.del(keys.stagesForProject(projectId));
    cache.del(keys.projectStages(projectId));
  }
  invalidateByPrefix("stages:");
}

export {
  cache,
  TTL,
  keys,
  getOrSet,
  invalidateByPrefix,
  invalidateProjects,
  invalidateTemplate,
  invalidateRoles,
  invalidateStages,
};
