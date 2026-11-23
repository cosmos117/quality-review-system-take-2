# Quality Review System (QRS) — Knowledge Transfer Document

> **Last updated:** 23 November 2026
> **Audience:** developers and IT staff who will run, maintain or extend QRS, plus project leads who need to understand how it works.
> **How to read this:** each section starts with a plain-language summary, followed by the technical details.

---

## Table of Contents

1. [What QRS Is](#1-what-qrs-is)
2. [How a Quality Review Works (the business flow)](#2-how-a-quality-review-works-the-business-flow)
3. [Architecture at a Glance](#3-architecture-at-a-glance)
4. [Technology Stack](#4-technology-stack)
5. [Repository Structure](#5-repository-structure)
6. [Backend Deep Dive](#6-backend-deep-dive)
7. [Frontend Deep Dive](#7-frontend-deep-dive)
8. [Running Everything Locally](#8-running-everything-locally)
9. [Deployment (On-Premises)](#9-deployment-on-premises)
10. [Maintenance & Backups](#10-maintenance--backups)
11. [Performance & Security Work (November 2026)](#11-performance--security-work-november-2026)
12. [Testing & Verification](#12-testing--verification)
13. [Troubleshooting](#13-troubleshooting)
14. [Known Issues & Recommendations](#14-known-issues--recommendations)
15. [Glossary](#15-glossary)

---

## 1. What QRS Is

**In simple terms:** QRS replaces spreadsheet-based quality checks. An admin defines *checklists* (what must be checked on a project). For every project, one person does the work and answers the checklist (the **executor**), and another person checks those answers (the **reviewer**). Wherever they disagree, the system counts a **defect**. Over time, QRS shows which projects, phases and defect categories cause the most problems.

**What it gives the organisation:**
- Standard checklist **templates**, reused across projects (e.g. "Piping Stress Analysis").
- A tracked **review workflow** per project phase: answer → submit → review → approve or send back.
- **Defect tracking** with categories, severity and a defect rate per phase and iteration.
- **Analytics dashboards** and a **master Excel export** for management.

---

## 2. How a Quality Review Works (the business flow)

### 2.1 Who uses the system

| Who | Account role (`User.role`) | What they do |
|---|---|---|
| **Admin** | `admin` | Manages users, checklist templates, defect categories and projects. Sees analytics. |
| **Employee** | `user` | Works on the projects they are assigned to, in a project role (below). |

Inside each project, an employee is assigned a **project role** (stored in the `Role` table and linked through `ProjectMembership`):

| Project role | Responsibility |
|---|---|
| **Team Leader** | Oversees the project and its team. |
| **Executor** | Does the engineering work and answers each checklist question (Yes / No / NA, a remark, optional photos). |
| **Reviewer** | Independently checks the executor's work, gives their own answer, and tags any problem with a defect category and severity. |

> **Technical note:** `User.role` (admin vs. user) controls *what screens and APIs* someone can use. The project role controls *what they do inside a project*. They are separate concepts.

### 2.2 The review cycle, step by step

1. **Admin creates a project** and picks a checklist template. When the project becomes active, the backend copies the template into the project: one **stage** (phase) per template stage, each with its own **project checklist**.
2. **Executor answers** each question in a phase. Answers save automatically as they work (autosave).
3. **Executor submits** the phase.
4. **Reviewer answers** the same questions. Wherever the executor's and reviewer's answers differ, the system counts a **defect**. The reviewer can tag it with a category (e.g. "Incorrect meshing") and a severity.
5. **Reviewer submits.** The defects found are added to the phase's running total.
6. Then one of two things happens:
   - **Approve:** the phase is marked `completed` and the next phase moves to `in_progress`. If it was the last phase, the whole project becomes `completed`.
   - **Revert to executor:** the current answers are saved as a snapshot (an **iteration**), the revert counter goes up, and the executor fixes the work and submits again. This can repeat; each round is a new iteration.
7. Throughout, the backend calculates the **defect rate** per phase and per iteration, and stores an **overall defect rate** on the project for dashboards.

### 2.3 Status values you will see in the data

| Thing | Values |
|---|---|
| Project status | `pending`, `in_progress`, `completed` (older data may also contain `Not Started` / `In Progress`) |
| Stage (phase) status | `pending`, `in_progress`, `completed` |
| Approval status (per project + phase) | `pending`, `approved`, `reverted_to_executor` |
| Executor answer | `Yes`, `No`, `NA`, or empty |
| Reviewer status | `Approved`, `Rejected`, or empty |

---

## 3. Architecture at a Glance

**In simple terms:** the app has three parts. A website (built with Flutter) runs in the user's browser and talks to a server (Node.js). The server is the only part that reads and writes the database (MySQL) and the folder of uploaded images.

```
 ┌──────────────────────────┐      HTTPS/HTTP + JSON       ┌──────────────────────────────┐
 │  Flutter Web app         │  ─────────────────────────▶  │  Node.js / Express API        │
 │  (runs in the browser)   │   Authorization: Bearer JWT  │  /api/v1/...                  │
 │  GetX state management   │  ◀─────────────────────────  │  auth · routes · services     │
 └──────────────────────────┘                              └───────┬───────────────┬──────┘
                                                                   │ Prisma ORM     │ fs
                                                                   ▼                ▼
                                                           ┌──────────────┐  ┌──────────────────┐
                                                           │   MySQL      │  │ backend/uploads/ │
                                                           │  (tables +   │  │ (checklist       │
                                                           │  JSON cols)  │  │  images)         │
                                                           └──────────────┘  └──────────────────┘
```

**Key design choices to know about:**
- **Checklist answers are stored as JSON.** Each project phase has one `ProjectChecklist` row whose `groups` column holds every group, section and question with both people's answers. This makes reading a whole checklist fast (one row), but every save rewrites that JSON. See §6.7 for how concurrent edits are kept safe.
- **Templates are also JSON** (`Template.stageData`, keyed `stage1`, `stage2`, …).
- **IDs** are 24-character hex strings (a carry-over from an earlier MongoDB version), generated by `backend/src/utils/newId.js`.

---

## 4. Technology Stack

| Area | Technology | Notes |
|---|---|---|
| Frontend | Flutter (Dart SDK ^3.9), **GetX** | Built for the web. `android/`, `ios/` etc. folders exist, but web is the supported target. |
| HTTP (frontend) | `package:http` | Wrapped by `SimpleHttp` in `lib/services/http_client.dart`. |
| Backend | Node.js (ES modules), **Express 5** | Entry point `backend/src/index.js`. |
| ORM | **Prisma 6.19.x** (pinned) | Schema in `backend/prisma/schema.prisma`. |
| Database | MySQL | The current `.env` points to a hosted MySQL; on-prem MySQL works the same. |
| Auth | JWT (`jsonwebtoken`), `bcrypt`, `cookie-parser` | Token sent as `Authorization: Bearer …` (also set as an httpOnly cookie). |
| Uploads | Multer (in-memory) → local disk | 10 MB max, JPG/PNG only. |
| Caching | `node-cache` (backend), `ApiCache` (frontend) | Short-lived, in-memory. |
| Excel | `exceljs` (backend), `excel` (frontend) | Master export and import/export features. |
| Logging | `winston` | Console output; level set by `LOG_LEVEL`. |

---

## 5. Repository Structure

```
.
├── backend/                     Node.js API
│   ├── prisma/schema.prisma     Database schema (no migrations folder; uses `db push`)
│   ├── seed.js                  Creates the first admin (and a demo reviewer) account
│   ├── seed-demo.js             Optional demo data (`npm run seed:demo`)
│   ├── uploads/                 Uploaded images (BACK THIS UP)
│   ├── src/
│   │   ├── index.js             Starts the server, connects to the DB
│   │   ├── app.js               Express setup: CORS, body limits, routes, error handler
│   │   ├── local_storage.js     Image save / read / delete on disk + DB metadata
│   │   ├── config/              Prisma client (prisma.js), DB-ready flag (db.js)
│   │   ├── middleware/          auth, admin check, request logger, login rate limit
│   │   ├── routes/              URL → controller mapping
│   │   ├── controllers/         Read the request, call a service, send the response
│   │   ├── services/            Business logic and database access
│   │   └── utils/               ApiError, ApiResponse, cache, logger, pagination, newId
│   ├── .env                     Secrets and configuration (NEVER commit real values)
│   └── package.json
├── frontend/                    Flutter app
│   ├── lib/
│   │   ├── main.dart            App entry; picks Admin or Employee layout after login
│   │   ├── bindings/            Registers services and controllers with GetX
│   │   ├── config/api_config.dart  API base URL (set at build time)
│   │   ├── controllers/         GetX controllers (state + logic per feature)
│   │   ├── services/            API clients (one per backend area) + ApiCache
│   │   ├── models/              Data classes
│   │   ├── pages/admin_pages/   Admin screens
│   │   ├── pages/employee_pages/ Employee screens (checklists, projects, performance)
│   │   ├── components/, widgets/ Reusable UI pieces
│   └── pubspec.yaml
├── render.yaml                  Old cloud (Render.com) deployment config, not used on-prem
└── KNOWLEDGE_TRANSFER.md        This document
```

**Backend layering rule:** `routes → controllers → services → Prisma`. Keep database code in services; controllers should stay thin.

---

## 6. Backend Deep Dive

### 6.1 Setup

```bash
cd backend
npm install          # also runs `prisma generate` (postinstall)
```

Use `npm ci` on servers: it installs exactly what `package-lock.json` specifies.

### 6.2 Environment variables (`backend/.env`)

**In simple terms:** this file holds passwords and settings. Every server has its own copy, and it must never be committed to Git with real values.

| Variable | Required | Purpose |
|---|---|---|
| `DATABASE_URL` | ✅ | MySQL connection: `mysql://USER:PASSWORD@HOST:PORT/DATABASE`. You can append `?connection_limit=10` to size Prisma's connection pool. |
| `ACCESS_TOKEN_SECRET` | ✅ | Long random string used to sign login tokens. Changing it logs everyone out. |
| `ACCESS_TOKEN_EXPIRY` | – | How long a login lasts. Default `7d`. |
| `COOKIE_SECRET` | ✅ | Long random string for signed cookies. |
| `PORT` | – | API port. Default `8000`. |
| `HOST` | – | Interface to listen on. Default `0.0.0.0` (all). |
| `NODE_ENV` | – | Set to `production` on servers (makes cookies `secure` + `sameSite=strict`). |
| `FRONTEND_URL` | – | Comma-separated list of allowed browser origins (CORS). See §6.10. |
| `LOG_LEVEL` | – | `error`, `warn`, `info` (default) or `debug`. |

> `MONGODB_URI` in the current `.env` is a leftover from the old MongoDB version and is not used. It can be removed.

### 6.3 Data model (database tables)

| Table | What it stores |
|---|---|
| `User` | Login accounts: name, email, bcrypt password hash, `role` (`admin`/`user`), and the current `accessToken`. |
| `Role` | Project roles (Team Leader, Executor, Reviewer, …). |
| `ProjectMembership` | Who is on which project, in which role. Unique per (project, user, role). |
| `Project` | Project details, status, `templateName` used, and the cached `overallDefectRate`. |
| `Stage` | The phases of a project (`stage_key` = `stage1`, `stage2`, …), status, and `conflict_count` (number of reverts). |
| `ProjectChecklist` | **One row per project phase.** `groups` (JSON) = the live checklist with all answers; `iterations` (JSON) = snapshots from each revert; `currentIteration`. |
| `ChecklistApproval` | Per project + phase: approval status, who submitted and when, `revertCount`. |
| `Template` | Checklist templates. `stageData` (JSON) holds the groups/sections/checkpoints per stage; `stageNames` holds the display names. |
| `ChecklistImage` | Metadata for each uploaded image (file path on disk, question, role, uploader, size). |
| `GlobalDefectCategory` / `…Settings` | The **global** list of defect categories and their groups, used by every project. |

**Shape of the checklist JSON (`ProjectChecklist.groups`):**

```jsonc
[
  {
    "groupName": "Input Verification & Modelling",
    "defectCount": 2,                       // running total, added at submit / revert
    "questions": [
      {
        "_id": "…24 hex…",
        "text": "Are pipe supports modelled correctly?",
        "executorAnswer": "Yes", "executorRemark": "", "executorImages": [],
        "reviewerAnswer": "No",  "reviewerStatus": "Rejected", "reviewerRemark": "Gap missing",
        "reviewerImages": [], "categoryId": "…", "severity": "High",
        "answeredBy": { "executor": "<userId>", "reviewer": "<userId>" },
        "answeredAt": { "executor": "ISO date", "reviewer": "ISO date" }
      }
    ],
    "sections": [ { "_id": "…", "sectionName": "…", "questions": [ /* same shape */ ] } ]
  }
]
```

**Applying schema changes:** edit `schema.prisma`, then run `npx prisma db push`. This changes the live database directly and keeps no migration history, so **back up the database first** and review what Prisma says it will change. Never accept a data-loss prompt on production without a backup.

### 6.4 API overview

All endpoints live under `/api/v1`. Responses usually look like `{ statusCode, data, message, success }`. Errors look like `{ statusCode, message, success: false, data: null }`.

| Area | Base path | Main operations |
|---|---|---|
| Users & login | `/users` | `POST /login`, `POST /logout`, `GET /` (list), `POST /register`, `PUT /:id`, `DELETE /:id`, `GET /:id/projects` |
| Project roles | `/roles` | List / create / update / delete roles |
| Projects | `/projects` | CRUD, `GET /:projectId/stages`, `PATCH /:projectId/sync-categories` |
| Members | `/projects/members` | List / add / update / remove project members |
| Stages | `/stages/:id`, `/projects/:projectId/stages` | Get / update / delete / create stages |
| Checklist answers | `/projects/:projectId/checklist-answers` | `GET` answers, `PUT` save (autosave), `POST /submit`, `GET /submission-status` |
| Project checklist | `/projects/:projectId/stages/:stageId/…` | Full checklist, iterations, per-question executor/reviewer updates, defect rates |
| Approvals | `/projects/:projectId/approval/…` | `compare`, `request`, `approve`, `revert-to-executor`, `status`, `revert-count` |
| Templates (library) | `/template-library` | `GET /list`, `GET /:name`, `POST /save` (save as new), `PUT /:name/save`, stage/checklist/section/checkpoint edits |
| Templates (legacy single) | `/templates` | Older single-template API, kept for compatibility |
| Defect categories | `/defect-categories` | `GET` (all users), `PATCH` (admin) |
| Analytics | `/analytics/…`, `/projects/:id/analysis…` | Dashboard summary, top categories, DR by project / team leader, etc. |
| Export | `/admin/export/master-excel` | Download the master Excel workbook |
| Images | `/upload-image`, `/images/:questionId`, `/images/file/:fileId` | Upload, list, download, delete |
| Health | `/health` (no `/api/v1`) | `{ status, uptime, databaseReady }`. Use for monitoring. |

### 6.5 Authentication: how login works

**In simple terms:** when you log in you get a "ticket" (a JWT). The app shows that ticket on every request. The server checks the ticket is genuine **and** that it is the latest one issued to you. Logging in again elsewhere replaces the ticket, so **each user has one active session at a time**.

**Technical flow** (`middleware/auth.Middleware.js`):
1. Read the token from the `token` cookie or the `Authorization: Bearer` header.
2. Verify the signature and expiry with `ACCESS_TOKEN_SECRET`.
3. Check the token equals `User.accessToken` in the database (logout sets this to `null`).
4. Attach the user to `req.user`.

**Session cache:** step 3 is cached in memory for **30 seconds** per user, which saves a database round-trip on almost every request. The cache entry is cleared immediately when that user logs in, logs out, is edited or is deleted (`invalidateUserSession` in `user.service.js`). The auth check also runs only once per request, even though several routers are mounted on overlapping paths.

**Login protection** (`middleware/loginRateLimit.js`): after **10 failed logins** for the same email from the same IP address, that combination is blocked (HTTP 429) until 15 minutes after the first failure. A successful login clears the counter.

### 6.6 Permissions: who can do what

**In simple terms:** the screens hide admin features from employees, **and the server enforces the same rules**. This matters because anyone with a valid login could otherwise call the API directly (from browser dev tools, Postman, etc.).

| Action | Who is allowed |
|---|---|
| Log in | Anyone (rate-limited) |
| Create a user account (`POST /users/register`) | **Admin only** (the first admin comes from `seed.js`) |
| Edit a user (`PUT /users/:id`) | Admin: anyone. Employee: **only themselves**, and **cannot change their role** |
| Delete a user | **Admin only** |
| Read templates | Any logged-in user (employee checklist screens need this) |
| Create / change / delete templates (both template APIs) | **Admin only** |
| Change global defect categories | **Admin only** |
| Everything else (projects, answers, approvals, images, analytics) | Any logged-in user. The UI controls who sees which button. |

The admin check is `requireAdmin` in `middleware/role.middleware.js` (it checks `req.user.role === "admin"`).

### 6.7 Saving answers safely (concurrency)

**The problem in simple terms:** the executor and the reviewer can be working on the same phase at the same time. Because the whole checklist is stored as one JSON value, two saves landing at the same moment used to mean *the second save silently erased the first person's change*.

**How it works now** (`updateChecklistGroups` in `services/projectChecklist.service.js`): this is **optimistic concurrency control**.
1. Read the checklist row, including its `updatedAt` timestamp.
2. Apply the change in memory.
3. Write it back **only if `updatedAt` hasn't changed** (`updateMany … where: { id, updatedAt }`).
4. If someone else saved in between, re-read the fresh data and apply the change again (up to 5 attempts). If it still can't save, the API returns **409** ("changed by someone else, please retry").

This protects autosave, single-question updates, submit, and revert. **Any new code that modifies `ProjectChecklist.groups` should use `updateChecklistGroups`** rather than a plain read-then-`update`.

### 6.8 Multi-step operations use transactions

**Approve** and **Revert to executor** each change several tables (approval record, stage statuses, project status, iteration snapshot, counters). They run inside a Prisma **interactive transaction** (15 s timeout), so they either fully succeed or fully roll back. A failure can no longer leave a phase "half approved".

Creating a project's stages and checklists from a template is also a single transaction. A project gets all of its phases or none, never just some.

### 6.9 Caching (server side)

| Cache | Where | Lifetime | Cleared when |
|---|---|---|---|
| Projects list / single project / project stages | `utils/cache.js` | 30–60 s | Project or stage changes |
| Templates | `utils/cache.js` | 120 s | Any template change |
| Global defect categories | `defect-category.service.js` | 5 min | Categories updated |
| Analytics raw data | `analytics-excel.service.js` | 30 s | User/project deletion, or expiry |
| Login sessions | `auth.Middleware.js` | 30 s | Login, logout, user update/delete |

All caches live **in the memory of one Node process**. If you ever run several backend processes (e.g. PM2 cluster mode), each one has its own cache, so changes can take up to the TTL to appear in the other processes.

The project's **overall defect rate** is recalculated in the background about 1.5 s after the last autosave (several quick saves trigger only one recalculation), and is only written to the database when its value actually changes.

### 6.10 CORS (which websites may call the API)

The rules are in `app.js`:
- Always allowed: requests with no browser origin (tools, server-to-server), `localhost`, and private LAN addresses (`192.168.x.x`, `10.x.x.x`, `172.16–31.x.x`).
- If `FRONTEND_URL` is set, only those origins are allowed in addition.
- If `FRONTEND_URL` is empty, all origins are allowed. Set it on production.

### 6.11 Request size limits

- JSON bodies: up to **5 MB**. This was 16 KB, which made "Save Template" / "Save As New Template" fail with 413 for real templates.
- Form bodies: 1 MB.
- Image uploads: **10 MB** per file, JPG/PNG only. The file's actual bytes are checked, not just its extension.

### 6.12 File storage (images)

- Files are saved under `backend/uploads/<project-name>/<stage>/<question-id>/<timestamp>-<random>.jpg|png`.
- Each file has a matching `ChecklistImage` row. The checklist JSON stores the image's **file id**.
- Downloads go through `GET /api/v1/images/file/:fileId` (requires login) and are sent with browser-cache headers (7 days). A file id never changes content, so browsers don't need to re-download images.
- Files are also reachable as static files under `/uploads/...` (see §14: this path does **not** require login).
- Deleting a project deletes its images (database rows and files) in bulk.

### 6.13 Logging & errors

- Every request is logged with method, URL, status and duration (`middleware/requestLogger.js`). 4xx responses are logged as warnings and 5xx as errors with a stack trace.
- Background jobs (template sync, stage creation, defect-rate refresh) log failures instead of failing silently.
- `index.js` exits the process on an unhandled error, so **run it under a service manager that restarts it** (§9.3).

---

## 7. Frontend Deep Dive

### 7.1 Setup

```bash
cd frontend
flutter pub get
```

### 7.2 Pointing the app at the API

The API address is **baked in at build time**:

```bash
flutter build web --release --dart-define=API_URL=http://<server-ip>:8000/api/v1
```

If you don't pass `API_URL`, it defaults to `http://localhost:8000/api/v1` (`lib/config/api_config.dart`). **A wrong URL means the app can't connect, and the only fix is to rebuild with the right one.**

### 7.3 How the code is organised (GetX)

- **`bindings/app_bindings.dart`** registers every service and controller once at startup (`Get.put` / `Get.lazyPut`).
- **Services** (`lib/services/*_service.dart`) are thin API clients, one per backend area. Most wrap their calls in **`ApiCache`**, which:
  - remembers results for a short time (typically 1–5 minutes),
  - merges duplicate requests made at the same moment into one,
  - is cleared after any change (create/update/delete), so the next read is fresh.
- **Controllers** (`lib/controllers/`) hold screen state as reactive values (`.obs`). Widgets wrapped in `Obx(...)` redraw automatically when those values change.
- **`main.dart`** watches the logged-in user. It shows the login page, the **Admin layout** (`role == admin`) or the **Employee layout**.
- **`SimpleHttp`** (`services/http_client.dart`) adds the `Authorization` header, applies a 15 s timeout, and **logs the user out automatically on any 401** (expired or replaced session).

### 7.4 Main screens

| Area | Screens (`lib/pages/…`) |
|---|---|
| Admin | Dashboard, Project details (assign team), Employees (users), Checklist Template Management, Analytics, Employee performance |
| Employee | Dashboard, My projects, Project detail, Checklist / Questions screen (executor & reviewer answering), Team-leader performance |

**Checklist Template Management** (admin): pick a template from the dropdown, edit phases, groups, sections and checkpoints, then:
- **Save Template**: writes the changes back to the selected template.
- **Save As New Template**: copies the current template under a new name (an empty or duplicate name is rejected with a message).
- **Manage Defect Categories**: edits the global category list used by all projects.

### 7.5 Background refreshes

| What | How often | Where |
|---|---|---|
| Projects list, team list | every 5 min | `projects_controller.dart`, `team_controller.dart` |
| Notification badges on "My projects" | every 20 s | `myproject.dart` → `notification_controller.dart` |

Notifications only make API calls for projects where the user is an **executor or reviewer**, and only for phases the project actually has.

---

## 8. Running Everything Locally

1. **Database:** have a MySQL instance and put its URL in `backend/.env` (§6.2).
2. **Schema:** `cd backend && npx prisma db push`
3. **First admin:** `node -r dotenv/config seed.js` (see `seed.js` for the default credentials, and **change that password straight away**).
4. **Start the API:** `npm run dev` (auto-reload) or `npm start`, then check `http://localhost:8000/health`.
5. **Start the app:** `cd ../frontend && flutter run -d chrome` (uses `localhost:8000` by default).

---

## 9. Deployment (On-Premises)

### 9.1 Server prerequisites
- A Windows or Linux VM with a fixed IP address / hostname on the company network.
- Node.js 18 or newer.
- MySQL 5.7+ / 8.x (or MariaDB), either on the same VM or reachable from it.

### 9.2 Firewall
- Open the API port (e.g. 8000) to users' machines.
- MySQL (3306) should only be reachable by the backend, never by end users.

### 9.3 Run the backend as a service
- **Linux:** a `systemd` unit, e.g. `/etc/systemd/system/quality-review.service`, running `npm start` in `backend/` with `Restart=always`.
- **Windows:** **NSSM** (or Task Scheduler) running `npm start` at boot, with restart-on-failure enabled.

Run **a single Node process** unless you accept the cache behaviour described in §6.9.

### 9.4 Deploy the web app
1. `flutter build web --release --dart-define=API_URL=http://<server>:8000/api/v1`
2. Copy `frontend/build/web/` to a web server (IIS, Nginx or Apache).
3. **Turn on gzip/brotli compression** on that web server. The main script is 3.8 MB raw but about 1.1 MB compressed.

### 9.5 Deployment checklist
- [ ] `NODE_ENV=production`, strong `ACCESS_TOKEN_SECRET` and `COOKIE_SECRET`
- [ ] `FRONTEND_URL` set to the real web address
- [ ] `npm ci` (not `npm install`) so the pinned Prisma version is used
- [ ] `npx prisma db push` only after a database backup
- [ ] `/health` returns `databaseReady: true`
- [ ] Backups scheduled (§10)
- [ ] If a reverse proxy sits in front of Node, add `app.set("trust proxy", 1)` in `app.js` so the login rate limit sees real client IPs

---

## 10. Maintenance & Backups

### 10.1 Database backup (daily)
```bash
mysqldump -u <user> -p<password> <database> | gzip > qrs_backup_$(date +%F).sql.gz
```
Keep copies on a separate network drive. **Test a restore occasionally.**

### 10.2 Uploaded files backup (daily)
Copy or `rsync` `backend/uploads/` alongside the database backup. The two must be restored **together**: the database points at the files.

### 10.3 Dependency updates
- Prisma is **pinned to `~6.19.3`** on purpose. Prisma 7 changes how the database URL is configured and would break startup. Upgrade deliberately, in a branch, and test.
- After changing `schema.prisma` or upgrading Prisma, run `npx prisma generate`.

---

## 11. Performance & Security Work (November 2026)

**In simple terms:** the app was made faster (far fewer database calls, especially important because each call crosses the network), several hidden bugs that lost data were fixed, and the server now enforces admin-only actions itself.

### 11.1 Bug fixes

| Problem | Effect before | Fix |
|---|---|---|
| JSON body limit of 16 KB | **Save Template / Save As New Template failed** (413) | Limit raised to 5 MB |
| Save-as wrote a non-existent `name` column | Save As New Template failed | Removed. Description is now copied instead |
| Two people saving the same phase at once | **One person's answers silently lost** | Optimistic concurrency (§6.7) |
| Approve / revert not atomic | Phase could be left half-approved | Transactions (§6.8) |
| Stage creation errors swallowed | Projects could get only some phases | Single transaction + error logging |
| Fallback-template query used `templateName: null` | The fallback could never work (Prisma validation error) | Query corrected |
| Defect categories added after the global-category change | Missing from analytics and the Excel export | Names also resolved from the global table |

### 11.2 Performance improvements

| Area | Before | After |
|---|---|---|
| Login check per request | 5–8 DB lookups | 1, then 0 within 30 s (cached) |
| Deleting a project with 200 images | ~400 DB queries | 2 |
| Answer autosave | DB write of defect rate on every save | One background recalculation per burst, written only if changed |
| Matching saved answers to questions | Nested scan per answer | One index lookup per answer |
| Analytics data build | Quadratic (projects × rows) | Linear |
| Phase list loading | Full template + 1 query per phase | 1 query (template only if needed) |
| Image upload / member changes | Sequential lookups | Parallel |
| Images in the browser | Re-downloaded on every redraw | Cached 7 days (immutable) |
| Notification polling | Up to 9 calls per project every 20 s for every user | Only for executors/reviewers, only for existing phases |
| Frontend cache | A slow old response could overwrite fresh data | Fixed |
| Frontend memory | 8 controllers never disposed | Disposed correctly |

### 11.3 Security improvements
- Account creation, user deletion and template changes are **admin-only on the server** (§6.6).
- Employees can no longer edit other users or **promote themselves to admin**.
- **Login rate limiting** (§6.5).
- Prisma version pinned, so `npm install` can't silently pull a breaking major version.

---

## 12. Testing & Verification

### 12.1 What exists
- **Frontend:** `flutter analyze` (lint) and `flutter test`, with one widget test that checks the login page appears.
- **Backend:** no automated test suite in the repository yet.

### 12.2 Checks to run before every release
```bash
# Backend
cd backend
for f in $(git ls-files src); do node --check "$f"; done   # syntax
npx prisma validate                                         # schema

# Frontend
cd ../frontend
flutter analyze          # expect 0 errors, 0 warnings
flutter test
flutter build web --release --dart-define=API_URL=...
```

### 12.3 Results of the November 2026 verification
Backend tests were run against the real Express app with the database replaced by an in-memory stand-in (no real data touched):

| Check | Result |
|---|---|
| Syntax, all 58 backend files | ✅ pass |
| Prisma schema validation | ✅ valid |
| Every GET endpoint (40 routes) on an empty database | ✅ no crashes |
| Performance & correctness checks | ✅ 7/7 |
| Permission / security checks | ✅ 17/17 (8 of them failed on the old code) |
| Session cache + bulk image delete | ✅ 3/3 |
| `flutter analyze` | ✅ 0 errors, 0 warnings (26 info-level notes) |
| `flutter test` / release web build | ✅ pass / builds |

**Still to be checked by hand on a real database before deploying:** approve and revert a phase, create a project from a template, Save As New Template, the analytics page, and the master Excel export.

### 12.4 Manual smoke test (after each deployment)
1. Log in as admin → dashboard loads.
2. Create a user; log in as that user in another browser.
3. Admin: create a project with a template, set it active, assign executor + reviewer.
4. Executor: answer a few questions, add a photo, submit.
5. Reviewer: answer differently on one question, tag a category, submit → a defect is counted.
6. Revert to executor → iteration 2 starts; executor resubmits; reviewer approves → next phase starts.
7. Analytics page and master Excel export show the defect.

---

## 13. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| **503** "Database connection is unavailable" | Backend can't reach MySQL | Check `DATABASE_URL`, that MySQL is running, firewall. Check `/health`. |
| App can't reach the API at all | Wrong `API_URL` at build time, or firewall/port | Rebuild the web app with the correct `--dart-define=API_URL=…`; check the port is open. |
| Browser console shows a **CORS** error | The site's address isn't allowed | Add it to `FRONTEND_URL` (comma-separated) and restart. |
| Users suddenly logged out | Token expired, the user logged in elsewhere (one session per user), or `ACCESS_TOKEN_SECRET` changed | Log in again. This is expected behaviour. |
| **403** "Admin access required" / "You can only update your own account" | Employee tried an admin action | Expected. Use an admin account. |
| **429** "Too many failed login attempts" | 10 wrong passwords for that email from that IP | Wait 15 minutes. Restarting the backend also clears it. |
| **409** "changed by someone else" | Very heavy simultaneous editing of one phase | Retry the action. Data is safe. |
| **413** on save | Body over 5 MB | Unusual. Check what is being sent. |
| Image upload fails | Over 10 MB, or not a real JPG/PNG | Resize or convert the image. |
| Analytics numbers lag slightly | Analytics cache (30 s) / project cache | Wait up to a minute, then refresh. |
| `npm start` fails after `npm install` with a Prisma error | Prisma version changed | Use `npm ci`; keep Prisma on 6.19.x; run `npx prisma generate`. |

---

## 14. Known Issues & Recommendations

**High priority**
1. **Uploaded images are publicly reachable** under `/uploads/...` without login (filenames are random, but the URL alone grants access). Fixing this requires the frontend to load images only via the authenticated `/api/v1/images/file/:id` route.
2. **Enable compression.** A typical checklist API response is 187 KB raw and about 8 KB gzipped (95% smaller). Either turn on gzip in the web server / reverse proxy, or add the `compression` Express middleware (one small dependency).
3. **Add an automated backend test suite** (e.g. Jest + Supertest against a disposable test database) so the checks in §12 run on every change.

**Medium priority**

4. **Reviewer "pending review" notifications never appear:** the frontend looks for statuses (`pending_review`, `submitted_for_review`) that the backend never sends. Needs a product decision on the intended rule.
5. **Very large screen files** (`checklist.dart`, `questions_screen.dart`, `admin_checklist_template_page.dart`, 2,000–2,800 lines each) are hard to maintain and redraw more than necessary. Split them into smaller widgets gradually, testing as you go.
6. `stage.service.js` uses "the first template in the database" when it creates missing checklists, not necessarily the project's own template. Review whether that is intended.
7. Remove unused leftovers: `MONGODB_URI` in `.env`, demo credentials in comments at the bottom of `frontend/lib/main.dart`, and the root-level `package.json` (it installs a second, older Prisma 5).
8. `ChecklistApproval` has an index that duplicates its unique key. It's harmless but redundant; removing it is a schema change, so do it with a backup.

**Low priority**

9. Login error messages ("User not found" vs. "Invalid credentials") reveal whether an email exists. Consider one generic message.
10. Consider a migration-based workflow (`prisma migrate`) instead of `db push` to keep a history of schema changes.

---

## 15. Glossary

| Term | Meaning |
|---|---|
| **Template** | A reusable checklist definition (phases → groups → sections → checkpoints). |
| **Stage / Phase** | One step of a project's review (e.g. Phase 1 "Input Verification"). Stored as `Stage`, keyed `stage1`, `stage2`, … |
| **Group / Section / Checkpoint (Question)** | Levels inside a checklist: a group contains questions and optional sections, which contain more questions. |
| **Executor** | Person who does the work and answers the checklist. |
| **Reviewer** | Person who checks the executor's answers. |
| **Defect** | A question where the executor's and reviewer's answers disagree (optionally tagged with a category + severity). |
| **Defect rate (DR)** | Defects ÷ total questions × 100, per phase / iteration. The project's overall DR is stored on `Project.overallDefectRate`. |
| **Iteration** | One round of answer → review. A revert saves a snapshot and starts the next iteration. |
| **Revert** | Reviewer sends the phase back to the executor for fixes. |
| **JWT** | JSON Web Token: the signed login "ticket" sent with each request. |
| **Prisma** | The library the backend uses to talk to MySQL. |
| **GetX** | The Flutter library used for state management and dependency injection. |
| **Optimistic concurrency** | Save only if the data hasn't changed since you read it; otherwise re-read and retry. |
| **TTL** | "Time to live": how long a cached value is kept. |
