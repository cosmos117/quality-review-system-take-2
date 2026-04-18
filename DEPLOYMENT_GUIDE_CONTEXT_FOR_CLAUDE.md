# Quality Review System - Deployment Guide Rewrite Context (Code-Aligned)

Use this file as the single source of truth to regenerate the company-facing deployment guide.
This context is aligned to the current repository implementation as of April 2026.

## 1) Rewrite Objective

Create a clean Deployment and Implementation Guide for Atlas Copco IT.
The guide must reflect the CURRENT implementation only.
The deployment target for this guide is on-premises infrastructure managed by Atlas Copco IT.

## 2) Scope Constraints

- Primary deployment target is Flutter Web + Node.js backend.
- Deployment model is on-premises (internal servers, internal network, company-managed firewall rules).
- Keep mobile (Android/iOS) out of deployment scope unless explicitly requested by stakeholders.
- Do not include app-store signing, APK/IPA packaging, or mobile MDM rollout steps.
- If platform capabilities are mentioned, phrase as "Flutter project structure includes mobile targets, but this guide covers web deployment only".
- Avoid SaaS/PaaS hosting assumptions unless leadership explicitly asks for a cloud deployment variant.

## 3) Current Stack (Verified)

- Backend: Node.js 18+, Express 5.1.0, Prisma ORM 6.4.0, MySQL.
- Frontend: Flutter (GetX), web build served as static assets.
- Auth: JWT token, accepted from cookie token or Authorization Bearer token.
- File upload: multer 2.0.0 using memory storage, then app code writes files to local disk.
- Logging: winston.
- Security middleware status (important for documentation accuracy): helmet is imported but currently disabled in app middleware, and express-rate-limit is installed but not mounted in app.js.

Evidence:

- backend/package.json
- backend/src/app.js
- backend/src/middleware/auth.Middleware.js
- backend/src/routes/images.js
- backend/src/local_storage.js

## 4) Environment Variables (Actually Used)

From backend/.env.example and runtime code:

- PORT (default 8000)
- NODE_ENV
- DATABASE_URL
- ACCESS_TOKEN_SECRET
- ACCESS_TOKEN_EXPIRY
- FRONTEND_URL
- COOKIE_SECRET
- LOG_LEVEL is also read by logger with default info.
- HOST is read by src/index.js with default 0.0.0.0 (not present in .env.example but supported).

## 5) CORS Behavior (Actual)

- CORS allows:
  - localhost/127.0.0.1
  - private LAN ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
  - explicit origins listed in FRONTEND_URL (comma-separated)
- If FRONTEND_URL is empty, fallback allows all origins.

## 6) Auth and Public Endpoint Reality

Do not state "only login/register are public". Current code exposes:

- Public: GET /health
- Public: GET /
- Public static files: /uploads/\*
- Public: POST /api/v1/users/register
- Public: POST /api/v1/users/login
- Public: GET /api/v1/roles and GET /api/v1/roles/:id

Most other API groups are mounted behind auth middleware in app.js.

## 7) Image Upload Architecture (Must Be Accurate)

- Upload endpoints:
  - POST /api/v1/images/:questionId (used by current Flutter flow)
  - POST /api/v1/upload-image (available but not used by current frontend)
- Limits and validation:
  - Max file size is 10 MB.
  - Allowed types jpg/jpeg/png.
  - Magic-byte validation performed after multer for real content verification.
- Storage flow:
  - multer memory buffer receives file.
  - local_storage writes file to backend/uploads/... path.
  - metadata row written to ChecklistImage table.
- Retrieval:
  - GET /api/v1/images/:questionId list
  - GET /api/v1/images/file/:fileId stream
- Frontend retrieval behavior:
  - Current frontend fetches image bytes through authenticated fileId endpoint (/api/v1/images/file/:fileId), not by directly consuming /uploads URLs in UI flows.
- Deletion:
  - DELETE /api/v1/images/file/:fileId deletes metadata and file.

Important wording correction:

- Do NOT write "multer writes files directly to disk".
- Correct wording is "multer buffers in memory; service layer writes to filesystem".

## 8) DB Model List (From schema.prisma)

Current Prisma models are:

- User
- Role
- Project
- ProjectMembership
- Stage
- ChecklistApproval
- Template
- ProjectChecklist
- ChecklistImage
- GlobalDefectCategory
- GlobalDefectCategorySettings

Do NOT claim these as Prisma models in the guide:

- Checklist
- Checkpoint
- ChecklistAnswer
- ChecklistTransaction

These names may still appear in business language and legacy code comments, but they are not Prisma models in the current schema file.

## 9) Role Semantics (Current)

- User registration API validates only roles user and admin.
- Seed script creates admin@gmail.com and reviewer@gmail.com (password admin).
- Frontend main router sends admin role to admin layout; non-admin users go to employee layout.

## 10) Security Notes to Phrase Carefully

- JWT is validated and also matched against User.accessToken in DB for session invalidation.
- requireAdmin middleware is used for selected routes (for example template admin flows and defect category updates), but not uniformly across all management endpoints.
- /uploads is publicly served in current implementation.

## 11) Web Deployment Commands (Reference)

Backend:

1. cd backend
2. npm install
3. copy .env.example to .env and set DATABASE_URL and ACCESS_TOKEN_SECRET
4. npx prisma db push
5. node seed.js (if seeding required)
6. npm run start (or npm run dev)

Frontend:

1. cd frontend
2. flutter pub get
3. flutter build web --release --dart-define=API_URL=http://<server-ip>:8000/api/v1
4. host frontend/build/web on an on-prem IIS/nginx/Apache static web server

## 12) Known Corrections to Apply in Drafts

- Replace any "5 MB" upload limit with 10 MB.
- Replace any statement that multer writes files directly to disk.
- Remove or rewrite route references that do not exist (for example /users/me if present).
- Replace outdated route file names (checklistRoutes.js, checklistAnswerRoutes.js, checkpoint.routes.js) with actual files in backend/src/routes.
- Ensure API auth section includes the actual public endpoints listed above.
- Do not document helmet or express-rate-limit as actively enforced middleware in the current runtime.
- Keep document web-deployment focused; mobile rollout steps should be omitted unless explicitly requested.
- In test-case wording, use browser file-picker language for current upload UX; avoid camera/gallery phrasing unless mobile scope is explicitly requested.
- Use on-premises terminology consistently (internal LAN/VPN deployment) in final guide wording.

## 13) Evidence Files to Cite in the New Guide

- backend/src/app.js
- backend/src/index.js
- backend/src/routes/images.js
- backend/src/local_storage.js
- backend/src/middleware/auth.Middleware.js
- backend/src/controllers/user.controller.js
- backend/src/services/user.service.js
- backend/src/routes/user.routes.js
- backend/src/routes/role.routes.js
- backend/prisma/schema.prisma
- backend/.env.example
- frontend/lib/config/api_config.dart
- frontend/lib/pages/employee_pages/checklist.dart
- backend/seed.js

## 14) Style Guidance for the Rewritten Guide

- Audience: Atlas Copco IT administrators and engineering leads.
- Tone: formal, implementation-accurate, no speculative claims.
- Prefer "as implemented" wording when behavior differs from ideal architecture.
- Include a short "Out of Scope" subsection clarifying mobile deployment is not covered in this guide version.
- Keep environment positioning explicit: this version of the guide is for on-premises deployment.
