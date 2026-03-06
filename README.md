# Quality Review System

A quality review and checklist management system with a Flutter frontend and Express.js backend.

---

## Project Structure

```
/
├── frontend/          # Flutter application
│   ├── lib/
│   │   ├── bindings/      # GetX dependency injection bindings
│   │   ├── components/    # Reusable UI components
│   │   ├── config/        # API configuration
│   │   ├── controllers/   # GetX controllers (state management)
│   │   ├── models/        # Dart data models
│   │   ├── pages/         # Screen-level widgets (admin & employee)
│   │   ├── services/      # HTTP service layer
│   │   └── widgets/       # Composite widgets
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── test/
│   └── pubspec.yaml
│
├── backend/           # Express.js API server
│   ├── src/
│   │   ├── config/        # Database connection
│   │   ├── controllers/   # Route handlers
│   │   ├── middleware/     # Auth & role middleware
│   │   ├── models/        # Mongoose schemas
│   │   ├── routes/        # API route definitions
│   │   ├── services/      # Business logic services
│   │   ├── utils/         # Helpers (ApiError, ApiResponse, asyncHandler)
│   │   └── scripts/       # DB migration scripts
│   ├── package.json
│   ├── .env.example
│   └── .gitignore
│
└── README.md
```

---

## Prerequisites

- **Flutter SDK** (3.x or later)
- **Node.js** (18.x or later) & npm
- **MongoDB** (Atlas or local instance)

---

## Getting Started

### 1. Backend Setup

```bash
cd backend

# Copy environment config and fill in your values
cp .env.example .env

# Install dependencies
npm install

# Start the server (production)
npm run start

# Or start with auto-reload (development)
npm run dev
```

The backend runs on **http://localhost:8000** by default.

### 2. Frontend Setup

```bash
cd frontend

# Get Flutter dependencies
flutter pub get

# Run the app (Chrome)
flutter run -d chrome

# Run the app (connected device / emulator)
flutter run
```

> **Note:** The Flutter app connects to the backend at `http://localhost:8000/api/v1` by default.
> To change this, edit `frontend/lib/config/api_config.dart`.

---

## Environment Variables (Backend)

| Variable | Description |
|---|---|
| `PORT` | Server port (default: 8000) |
| `MONGO_DB_URI` | MongoDB connection URI |
| `DB_NAME` | Database name |
| `CORS_ORIGIN` | Allowed CORS origins |
| `ACCESS_TOKEN_SECRET` | JWT signing secret |
| `ACCESS_TOKEN_EXPIRY` | JWT expiry duration (e.g., `1d`) |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart), GetX |
| Backend | Express.js 5, Node.js |
| Database | MongoDB (Mongoose) |
| Auth | JWT + bcrypt |
| File Storage | MongoDB GridFS |
