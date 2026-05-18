import NodeCache from "node-cache";

// Cache TTL in seconds
const TTL = {
  PROJECTS: 30,
  PROJECT_BY_ID: 60,
  PROJECT_STAGES: 60,
  TEMPLATES: 120,
  ROLES: 120,
  STAGES: 60,
};

const cache = new NodeCache({ stdTTL: 60, checkperiod: 30 });

// Key builders

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

// Returns cached value or fetches, caches, and returns fresh data
async function getOrSet(key, fetchFn, ttl) {
  const cached = cache.get(key);
  if (cached !== undefined) return cached;

  const data = await fetchFn();
  if (data !== undefined && data !== null) {
    cache.set(key, data, ttl);
  }
  return data;
}

// Clears all cache keys starting with the given prefix
function invalidateByPrefix(prefix) {
  const allKeys = cache.keys();
  const toDelete = allKeys.filter((k) => k.startsWith(prefix));
  if (toDelete.length > 0) cache.del(toDelete);
}

// Invalidation helpers per domain

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
