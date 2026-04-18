# Context Document: Quality Review System — Updated Deployment Guide

### Purpose

This file contains all the accurate, current technical context needed for Claude to rewrite the
"Quality Review System – Deployment & Implementation Guide" for Atlas Copco (IT Department).
The original guide was written when the project used MongoDB + Mongoose + GridFS.
**Everything has since migrated.** Use only the facts below when producing the new document.

---

## 1. What Changed (Migration Summary)

| Area                 | Old (Deprecated – DO NOT document) | New (Current – Document this)                                        |
| -------------------- | ---------------------------------- | -------------------------------------------------------------------- |
| Database             | MongoDB 6.0 / MongoDB Atlas        | MySQL (hosted on **Aiven** cloud)                                    |
| ORM / Schema         | Mongoose                           | **Prisma ORM v6** (`@prisma/client ^6.4.0`)                          |
| File / Image Storage | MongoDB GridFS                     | **Local server disk** (`backend/uploads/`) + metadata in MySQL       |
| Schema file          | Mongoose model files               | `backend/prisma/schema.prisma`                                       |
| DB connection var    | `MONGODB_URI`                      | `DATABASE_URL`                                                       |
| DB push command      | (none)                             | `npx prisma db push`                                                 |
| Client generation    | (none)                             | `npx prisma generate` (auto-runs on `npm install` via `postinstall`) |

> **CRITICAL**: Remove all references to MongoDB, Mongoose, and GridFS from the new document.
> Replace every mention of `MONGODB_URI` with `DATABASE_URL`.

---

## 2. Technology Stack (Current)

| Component           | Technology                      | Version / Notes                                                              |
| ------------------- | ------------------------------- | ---------------------------------------------------------------------------- |
| Frontend            | Flutter (Dart) + GetX           | Flutter 3.x stable                                                           |
| Backend             | Express.js + Node.js            | Express v5 (`^5.1.0`), Node.js 18+                                           |
| Database            | MySQL                           | Aiven cloud-hosted MySQL (recommended) or local MySQL 8+                     |
| ORM                 | Prisma                          | `@prisma/client ^6.4.0`, `prisma ^6.4.0`                                     |
| Auth                | JWT + bcrypt                    | `jsonwebtoken ^9.0.3`, `bcrypt ^6.0.0`                                       |
| Image Storage       | Local disk (`backend/uploads/`) | Served as static files via Express; metadata in MySQL `ChecklistImage` table |
| Security            | helmet, express-rate-limit      | `helmet ^8.1.0`, `express-rate-limit ^8.3.0`                                 |
| Logging             | winston                         | `winston ^3.19.0`                                                            |
| Caching             | node-cache                      | `node-cache ^5.1.2`                                                          |
| Export              | exceljs                         | `exceljs ^4.4.0`                                                             |
| File upload handler | multer                          | `multer ^2.0.0` – images buffered in memory, then written to disk            |

---

## 3. Environment Variables (Current `.env.example`)

```
PORT=8000
NODE_ENV=development

# MySQL Database Connection
DATABASE_URL="mysql://avnadmin:PASSWORD@IP_ADDRESS:14382/defaultdb?ssl-mode=REQUIRED"

ACCESS_TOKEN_SECRET=your_secret_key_here
ACCESS_TOKEN_EXPIRY=1d
FRONTEND_URL=
COOKIE_SECRET=your_cookie_secret_here
```

### Variable Reference Table

| Variable              | Required | Description                                                                                               |
| --------------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| `PORT`                | No       | Server port. Default: `8000`                                                                              |
| `NODE_ENV`            | No       | `development` or `production`                                                                             |
| `DATABASE_URL`        | **Yes**  | Full Prisma-compatible MySQL connection string (see note below)                                           |
| `ACCESS_TOKEN_SECRET` | **Yes**  | Secret for signing JWT tokens (use a long random string)                                                  |
| `ACCESS_TOKEN_EXPIRY` | No       | JWT expiry. Default: `1d`                                                                                 |
| `FRONTEND_URL`        | No       | Comma-separated allowed CORS origins (e.g. `http://192.168.1.45:5000`). Blank = allow all LAN + localhost |
| `COOKIE_SECRET`       | No       | Cookie signing secret                                                                                     |

**DATABASE_URL format note:**

- For Aiven MySQL (production): `mysql://avnadmin:PASSWORD@HOST:PORT/defaultdb?ssl-mode=REQUIRED`
- For local MySQL: `mysql://user:password@localhost:3306/your_db_name`
- Prisma requires `sslmode=require&sslaccept=strict` style for SSL (not CLI-style `--ssl-mode`). The Aiven connection string uses `ssl-mode=REQUIRED` which Prisma accepts.

---

## 4. Backend Setup (Step-by-Step)

```bash
# Step 1 – Clone and navigate to backend
git clone <repository-url>
cd quality-review-system-take-2/backend

# Step 2 – Copy env template and fill in values
cp .env.example .env
# Edit .env — set DATABASE_URL and ACCESS_TOKEN_SECRET at minimum

# Step 3 – Install dependencies
# NOTE: npm install also runs "npx prisma generate" automatically (postinstall hook)
npm install

# Step 4 – Push database schema to MySQL
npx prisma db push
# (Only needed on first setup or when schema.prisma changes)

# Step 5 – Seed initial data (creates default admin + reviewer accounts)
node seed.js

# Step 6 – Start the server
npm run start    # production
npm run dev      # development with auto-reload (nodemon)
```

The API will be available at `http://<server-ip>:8000`.
Health check: `GET http://<server-ip>:8000/health` → returns `{ "status": "ok", "uptime": ... }`

---

## 5. Frontend Setup (Web)

The Flutter app receives the backend URL at **build/run time** via `--dart-define=API_URL=...`.
There is **no hardcoded URL** in the codebase; the default fallback is `http://localhost:8000/api/v1`.

```bash
# Navigate to frontend
cd frontend

# Install Flutter dependencies
flutter pub get

# Run (development / LAN serving)
flutter run -d chrome --dart-define=API_URL=http://<server-ip>:8000/api/v1

# Build for production (static files)
flutter build web --release --dart-define=API_URL=http://<server-ip>:8000/api/v1
```

After building, serve `frontend/build/web/` with any static file server (nginx, IIS, Apache).
The config file is at `frontend/lib/config/api_config.dart` — it reads `API_URL` from `--dart-define`.

---

## 6. Image / File Storage System (Special Section — Read Carefully)

This is the most significant architectural change from the original document and needs
**its own clearly explained section** in the deployment guide.

### How It Works (Current Architecture)

1. **Upload**: The Flutter app sends a `multipart/form-data` POST to `/api/v1/images/:questionId`
   or `/api/v1/upload-image`. multer buffers the file in memory on the server.
2. **Validation**: The backend validates MIME type and file extension (JPG/PNG only, max 10 MB).
   It also detects the true image type from the file's binary header (magic bytes) because
   Flutter Web sometimes sends `application/octet-stream` regardless of the actual image type.
3. **Storage**: The image buffer is written to disk under `backend/uploads/` with a structured
   path: `uploads/<projectId>/<checklistId>/<questionId>/<timestamp>-<random>.<ext>`
4. **MySQL Metadata Record**: After writing the file, a record is inserted into the
   `ChecklistImage` table in MySQL (via Prisma) containing: `id`, `project_id`, `checklist_id`,
   `defect_id`, `question_id`, `image_path` (relative path), `uploaded_by`, `role`,
   `original_name`, `mime_type`, `size_bytes`, `created_at`.
5. **Serving**: Images are served as **static files** by Express at the `/uploads/` public route.
   The response from the upload endpoint returns both a relative `image_path` and an absolute
   `image_url` (e.g. `http://<server-ip>:8000/uploads/<project>/<checklist>/<question>/file.jpg`).
6. **Retrieval**: `GET /api/v1/images/:questionId` → list all images for a question (optionally
   filtered by `?role=executor` or `?role=reviewer`).
   `GET /api/v1/images/file/:fileId` → stream the raw image bytes from disk.
7. **Deletion**: `DELETE /api/v1/images/file/:fileId` → removes the MySQL record AND deletes the
   file from disk.

### Key Operational Notes for IT Deployments

- The `backend/uploads/` directory is **created automatically** on first start (no manual setup needed).
- **Disk space planning**: Uploads accumulate over time. Plan for sufficient disk space on the
  backend server (minimum 20 GB recommended).
- **Backups**: The `uploads/` folder must be included in server backups alongside the MySQL database.
  If the MySQL `ChecklistImage` rows exist but the physical files are missing (or vice versa),
  images will appear broken in the UI.
- **Multi-server / load balancer deployments**: Because images are stored to the local disk of the
  backend server, all backend instances must share the same filesystem (e.g. mounted NFS or a shared
  network drive). A single-server deployment has no such constraint.
- **No cloud object storage** (S3, GCS, etc.) is used. Everything is local disk.
- The `/uploads/` route is served publicly without authentication — any user on the network who
  knows the URL can access an image directly. In a production environment, consider restricting
  access if confidentiality is required.

### Testing / Validation (Image Upload Flow)

| Test Case                  | Steps                                                          | Expected Result                                                                                       |
| -------------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Upload JPG via Flutter     | Open a checklist, attach a photo via the camera/gallery picker | Server writes file to `backend/uploads/…`, returns `image_url`, image appears inline in the checklist |
| Upload PNG via Flutter Web | Same as above but from browser file picker                     | File validated via magic bytes (not MIME header), stored correctly                                    |
| Retrieve image             | Open a submitted checklist as Admin; view uploaded photos      | Image loads from `http://<server>:8000/uploads/…` URL                                                 |
| Invalid file type rejected | Try to upload a PDF or `.txt` file                             | Returns HTTP 400: `"Only JPG and PNG images are allowed"`                                             |
| Oversized file rejected    | Upload image > 10 MB                                           | Returns HTTP 400: `"Image size exceeds 10MB limit"`                                                   |
| Delete image               | Admin deletes an attachment from a submission                  | MySQL record removed, file deleted from disk, image no longer accessible                              |
| Disk persistence check     | Restart the backend server; re-open a submission with images   | Images still load (files persist on disk; MySQL metadata intact)                                      |

---

## 7. Database Schema Summary (Prisma / MySQL)

The schema is defined in `backend/prisma/schema.prisma`. Key models:

| Model                          | Purpose                                                                                |
| ------------------------------ | -------------------------------------------------------------------------------------- |
| `User`                         | All users (admin + employee). Fields: id, name, email, password (bcrypt), role, status |
| `Role`                         | Named roles (e.g. Executor, Reviewer) assignable to project members                    |
| `Project`                      | Quality review projects with status, priority, dates, templateName                     |
| `ProjectMembership`            | Many-to-many: User ↔ Project ↔ Role                                                    |
| `Stage`                        | Stages within a project (e.g. stage1…stage12)                                          |
| `Checklist`                    | Individual checklist instances per stage. Stores answers as JSON                       |
| `Checkpoint`                   | Individual checklist questions/items                                                   |
| `ChecklistAnswer`              | Per-question answers (executor + reviewer roles), includes images JSON field           |
| `ChecklistApproval`            | Approval workflow state per project phase                                              |
| `ChecklistTransaction`         | Audit trail of checklist actions (CREATED, SUBMITTED, APPROVED, etc.)                  |
| `Template`                     | Admin-defined checklist templates with stage names, defect categories, stage data      |
| `ProjectChecklist`             | Links a project stage to its live checklist groups + iterations                        |
| `ChecklistImage`               | **Image metadata** — file path, question/project/checklist association, uploader       |
| `GlobalDefectCategory`         | Company-wide defect categories with keywords and groups                                |
| `GlobalDefectCategorySettings` | Settings for defect category groupings                                                 |

---

## 8. CORS Configuration

- CORS is configured in `backend/src/app.js`.
- **Always allowed without configuration**: `localhost`, `127.0.0.1`, and all private LAN ranges
  (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`).
- If `FRONTEND_URL` is set in `.env`, only those origins (comma-separated) are additionally allowed.
- If `FRONTEND_URL` is blank, all origins are allowed (fallback for development).
- In production set `FRONTEND_URL` to the exact Flutter web origin to lock it down.

---

## 9. API Route Reference (Summary)

All routes start with `/api/v1/` and require JWT auth except `/api/v1/users/login` and `/api/v1/users/register`.

| Area               | Routes file                                      | Key endpoints                                          |
| ------------------ | ------------------------------------------------ | ------------------------------------------------------ |
| Users / Auth       | `user.routes.js`                                 | POST /users/login, POST /users/register, GET /users/me |
| Roles              | `role.routes.js`                                 | CRUD for roles                                         |
| Projects           | `project.routes.js`                              | CRUD for projects                                      |
| Project Membership | `projectMembership.routes.js`                    | Add/remove members from projects                       |
| Stages             | `stage.routes.js`                                | CRUD for project stages                                |
| Checklists         | `checklistRoutes.js`                             | CRUD for checklist instances                           |
| Checklist Answers  | `checklistAnswerRoutes.js`                       | Save/get per-question answers                          |
| Checkpoints        | `checkpoint.routes.js`                           | Checklist checkpoint items                             |
| Approvals          | `approval.routes.js`                             | Submit for review, approve, revert                     |
| Project Checklists | `projectChecklist.routes.js`                     | Live checklist state per project stage                 |
| Templates          | `template.routes.js`, `template.multi.routes.js` | Admin template management                              |
| Analytics          | `analytics.routes.js`                            | Defect rates, submission stats                         |
| Export             | `export.routes.js`                               | Excel export of submissions                            |
| Images             | `images.js`                                      | Upload, list, download, delete images                  |
| Defect Categories  | `defect_category_routes.js`                      | Global defect category management                      |

---

## 10. Default Seed Accounts (After running `node seed.js`)

| Role     | Email              | Password |
| -------- | ------------------ | -------- |
| Admin    | admin@gmail.com    | admin    |
| Reviewer | reviewer@gmail.com | admin    |

> **Security note for production**: Change these credentials immediately after first deployment.

---

## 11. Backend Directory Structure (Current)

```
backend/
├── src/
│   ├── app.js              # Express app: CORS, middleware, route mounting
│   ├── index.js            # Server entry point (starts express, connects DB)
│   ├── local_storage.js    # Image storage service (disk writes + MySQL metadata)
│   ├── config/             # Prisma client initialization
│   ├── controllers/        # Route handler functions
│   ├── middleware/         # JWT auth middleware, request logger
│   ├── routes/             # API route definitions (including images.js)
│   ├── services/           # Business logic
│   └── utils/              # ApiError, ApiResponse, asyncHandler, logger, newId
├── prisma/
│   └── schema.prisma       # Prisma schema (MySQL) — single source of truth for DB
├── uploads/                # Image files stored here (auto-created, not in git)
├── seed.js                 # Seeds default admin + reviewer accounts + roles
├── .env.example            # Environment variable template
├── package.json            # Scripts: start, dev, postinstall (prisma generate)
└── .gitignore
```

---

## 12. Port and Network Reference

| Port     | Protocol | Purpose                                      | Accessibility                                |
| -------- | -------- | -------------------------------------------- | -------------------------------------------- |
| 8000     | TCP      | Express.js API + static image serving        | Open to client machines                      |
| 14382    | TCP      | Aiven MySQL (cloud)                          | Backend server only (no need to open on LAN) |
| 3306     | TCP      | Local MySQL (if used)                        | Backend server only                          |
| 80 / 443 | TCP      | Web server for Flutter frontend static build | Open to client machines                      |

---

## 13. Troubleshooting Reference (Updated)

| Issue                              | Resolution                                                                                                      |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Backend fails to start             | Check Node.js ≥ 18 (`node --version`). Run `npm install`. Check `.env` exists with valid `DATABASE_URL`.        |
| `PrismaClientInitializationError`  | `DATABASE_URL` is wrong or Aiven IP is not whitelisted. Verify the connection string format and SSL parameters. |
| Database schema out of sync        | Run `npx prisma db push` to push schema changes to MySQL.                                                       |
| Prisma client not found            | Run `npx prisma generate` (or re-run `npm install`).                                                            |
| JWT authentication errors          | Ensure `ACCESS_TOKEN_SECRET` is set. Clear browser cookies and retry.                                           |
| CORS errors in browser             | Set `FRONTEND_URL` in `.env` to the exact Flutter web origin (e.g. `http://192.168.1.45:5000`).                 |
| Flutter web cannot reach backend   | Confirm `--dart-define=API_URL=` matches backend address. Check firewall on port 8000.                          |
| Image upload fails (400)           | Ensure file is JPG or PNG and under 10 MB.                                                                      |
| Image displays broken after upload | Check `backend/uploads/` directory exists and is writable. Confirm MySQL `ChecklistImage` record was created.   |
| Image lost after server migration  | The `uploads/` directory was not copied to the new server. Always back up `uploads/` with the database.         |
| `npm install` fails                | Check internet. Run `npm cache clean --force`, retry. Verify Node.js and npm versions.                          |
| Employee cannot see templates      | Admin must have created and published templates. Check role middleware assignment at registration.              |

---

## 14. Production Recommendations

- Use **PM2** to manage the Node.js backend process:
  ```bash
  npm install -g pm2
  pm2 start src/index.js --name quality-review-backend
  pm2 logs quality-review-backend
  pm2 startup   # auto-restart on reboot
  ```
- Serve the Flutter web build via **nginx** or **IIS** on port 80/443.
- Set `NODE_ENV=production` in `.env`.
- Set `FRONTEND_URL` to the exact web origin to restrict CORS.
- Schedule regular backups of both the **Aiven MySQL database** and the **backend/uploads/ folder**.
- Rotate `ACCESS_TOKEN_SECRET` periodically (invalidates all active sessions).
- Do **not** commit `.env` to version control (already gitignored).

---

## 15. Updating the Application

```bash
# 1. Pull latest code
git pull origin main

# 2. Re-install backend dependencies if package.json changed
cd backend && npm install

# 3. Push any new schema changes to MySQL
npx prisma db push

# 4. Rebuild Flutter web if frontend code changed
cd ../frontend
flutter build web --release --dart-define=API_URL=http://<server-ip>:8000/api/v1

# 5. Restart backend
pm2 restart quality-review-backend

# 6. Redeploy Flutter static build to web server directory
# Copy frontend/build/web/ to nginx/IIS root

# 7. Clear browser cache on client machines after major frontend updates
```
