# Quality Review System - Knowledge Transfer Document

## 1. Introduction & Vision

### 1.1. Project Purpose & Goals
This document provides a comprehensive overview of the Quality Review System, a project designed to streamline and standardize quality assurance processes. It serves as a central knowledge base for future development teams, project managers, and stakeholders at Atlas Copco.

The primary goal of the system is to provide a robust platform for:
- Defining quality checklists and templates.
- Conducting quality reviews on projects.
- Tracking defects and approvals.
- Analyzing quality metrics over time.

### 1.2. High-Level Architecture
The system is built on a modern client-server architecture:

- **Backend**: A Node.js (Express) application that serves a RESTful API for all data operations.
- **Database**: A MySQL database managed via the Prisma ORM.
- **Frontend**: A cross-platform application built with Flutter, supporting both Android mobile and a web-based client.
- **File Storage**: The backend uses the local file system for storing uploaded images and other assets in the `backend/uploads` directory.

---

## 2. Technology Stack

| Category      | Technology/Library                               |
|---------------|--------------------------------------------------|
| **Backend**   | Node.js, Express.js, Prisma, JWT (for auth)      |
| **Database**  | MySQL                                            |
| **Frontend**  | Flutter, Dart                                    |
| **DevOps**    | Git, systemd (Linux), Task Scheduler (Windows)   |

---

## 3. Workspace & Project Structure

The project is organized as a monorepo to simplify development and deployment.

```
.
├── backend/         # Node.js Express API
│   ├── prisma/      # Prisma schema and migrations
│   ├── src/         # Main source code
│   │   ├── controllers/
│   │   ├── middleware/
│   │   ├── routes/
│   │   └── services/
│   ├── .env         # Environment variables (CRITICAL)
│   └── package.json
├── frontend/        # Flutter application (Mobile & Web)
│   ├── lib/         # Main Dart source code
│   │   ├── config/  # API configuration
│   │   ├── controllers/
│   │   ├── models/
│   │   └── pages/
│   └── pubspec.yaml
├── KNOWLEDGE_TRANSFER.md # This document
└── render.yaml      # Deployment configuration for Render (if used)
```

---

## 4. Backend Deep Dive

### 4.1. Setup and Installation
1. Navigate to the `backend` directory: `cd backend`
2. Install dependencies: `npm install`

### 4.2. Environment Configuration (`.env`)
The backend requires a `.env` file in the `backend` directory for configuration. This file is critical and **must not** be committed to version control with production secrets.

**Critical Variables:**
- `DATABASE_URL`: The connection string for the MySQL database.
  - Format: `mysql://USER:PASSWORD@HOST:PORT/DATABASE`
- `FRONTEND_URL`: The public URL of the frontend application.
- `ACCESS_TOKEN_SECRET`: A long, random string for signing JWTs.
- `COOKIE_SECRET`: A long, random string for securing cookies.
- `PORT`: The port for the backend server (e.g., 8000).
- `NODE_ENV`: Set to `production` for deployments.

### 4.3. Database Schema & Migrations (Prisma)
The database schema is defined in `backend/prisma/schema.prisma`.

To apply schema changes to the database, run:
`npx prisma db push`

This command updates the database schema to match the `schema.prisma` file without generating a migration history.

### 4.4. API Endpoints & Authentication
- **Authentication**: The API uses JSON Web Tokens (JWTs) for authentication. The login endpoint (`/api/v1/auth/login`) returns a token that must be included in the `Authorization` header for protected routes.
- **Authorization**: Role-based access control is implemented in the `backend/src/middleware/role.middleware.js`.
- **Routes**: All API routes are defined in the `backend/src/routes/` directory.

### 4.5. File Storage & Uploads
- **Storage**: The backend stores all uploaded files on the local file system in the `backend/uploads/` directory.
- **Upload Limit**: There is a hardcoded upload limit of **10 MB** per file, enforced in `backend/src/routes/images.js`.

### 4.6. Running the Backend Locally
1. Ensure your `.env` file is correctly configured.
2. Apply database schema: `npx prisma db push`
3. Start the server: `npm start`
4. The API will be available at `http://localhost:8000` (or the port specified in `.env`).
5. A health check endpoint is available at `/health`.

---

## 5. Frontend Deep Dive

### 5.1. Setup and Installation
1. Ensure you have the Flutter SDK installed.
2. Navigate to the `frontend` directory: `cd frontend`
3. Install dependencies: `flutter pub get`

### 5.2. Configuration
The backend API URL is configured during the build process. It is not hardcoded, allowing for different configurations between development and production.

### 5.3. Building for Android
`flutter build apk --dart-define=API_URL=http://<your-server-ip>:8000/api/v1`

The resulting APK will be in `frontend/build/app/outputs/flutter-apk/`.

### 5.4. Building for Web
`flutter build web --dart-define=API_URL=http://<your-server-ip>:8000/api/v1`

The static web files will be in `frontend/build/web/`. These files can be served by any static web server.

---

## 6. Deployment (On-Premises)

This guide assumes deployment to a local server on the company network.

### 6.1. Server Prerequisites
- A server (Windows or Linux) with a static IP address.
- Node.js (v18 or newer).
- MySQL (v5.7 or newer) or MariaDB.

### 6.2. Firewall Configuration
- **Inbound Rule**: Allow TCP traffic on the backend port (e.g., 8000) to allow clients to connect to the API.
- **Database Port**: Ensure the backend server can connect to the MySQL port (default 3306). This port should **not** be exposed publicly.

### 6.3. Backend Service Setup
For the backend to run continuously, it should be configured as a service.

- **Linux**: Create a systemd unit file at `/etc/systemd/system/quality-review.service`.
- **Windows**: Use a tool like **NSSM (Non-Sucking Service Manager)** or Windows Task Scheduler to run the `npm start` command on startup.

### 6.4. Deploying the Frontend
- **Web**: Place the contents of the `frontend/build/web` directory into the document root of a web server (like Nginx or Apache) or serve them from the Node.js backend itself.
- **Android**: The built APK file must be manually distributed and installed on user devices.

---

## 7. System Maintenance

### 7.1. Database Backup Strategy
Regular backups of the MySQL database are critical.

- **Method**: Use `mysqldump` to create a daily backup of the database.
- **Command**: `mysqldump -u <user> -p<password> <database_name> | gzip > quality_review_backup_$(date +%F).sql.gz`
- **Storage**: Store backups on a separate, secure network drive or cloud storage.

### 7.2. File Storage Backup
The `backend/uploads/` directory contains all user-uploaded files and must be backed up regularly.

- **Method**: A simple file copy or a scheduled `rsync` job.
- **Frequency**: Daily, in conjunction with the database backup.

---

## 8. Troubleshooting

| Problem                               | Solution                                                                                                                            |
|---------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| **503 Service Unavailable**           | The backend cannot connect to the MySQL database. Check the `DATABASE_URL` in the `.env` file and ensure the database server is running. |
| **Image Upload Fails**                | The file may be larger than the 10 MB limit. Check the backend logs for "File too large" errors.                                      |
| **Frontend Can't Connect to API**     | The `API_URL` was likely misconfigured during the build. Rebuild the frontend with the correct server IP address.                     |
| **Permission Denied Errors**          | The user's role does not have the required permissions for the action. Check the `role.middleware.js` and the user's assigned role.   |

