import fs from "node:fs";
import path from "node:path";
import { defineConfig } from "prisma/config";

// Prefer backend/.env for this repo, then fall back to root .env.
for (const relativePath of ["backend/.env", ".env"]) {
  if (process.env.DATABASE_URL) break;
  const absolutePath = path.resolve(process.cwd(), relativePath);
  if (fs.existsSync(absolutePath)) {
    process.loadEnvFile(absolutePath);
  }
}

if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL is missing. Set it in backend/.env, .env, or your shell environment.",
  );
}

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: process.env.DATABASE_URL,
  },
});
