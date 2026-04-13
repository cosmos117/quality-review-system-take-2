# Getting Started Guide

Welcome to the Quality Review System! This guide will walk you through setting up the development environment on your local machine.

---

## 📋 Prerequisites

Ensure you have the following installed:

- **[Node.js](https://nodejs.org/)** (v18 or higher recommended)
- **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (Stable channel)
- **[MySQL](https://www.mysql.com/)** (Optional, if you want to run a local database)
- **Git**

---

## 🚀 Step 1: Clone the Repository

```bash
git clone <repository-url>
cd quality-review-system-take-2
```

---

## ⚙️ Step 2: Backend Setup

### 1. Install Dependencies
```bash
cd backend
npm install
```
*Note: This will also automatically run `npx prisma generate` to create the Prisma client.*

### 2. Configure Environment Variables
Create a `.env` file in the `backend/` directory. You can copy the template:
```bash
cp .env.example .env
```
Then, update the `DATABASE_URL` in `.env`.
- **Option A (Shared Cloud DB):** Use the Aiven MySQL URL provided by the team.
- **Option B (Local DB):** `mysql://user:password@localhost:3306/your_db_name`

### 3. Sync Database Schema
If you are using a fresh local database, run:
```bash
npx prisma db push
```

### 4. Seed Initial Data
To create the default admin account and roles, run:
```bash
node seed.js
```

### 5. Start the Backend
```bash
npm run dev
```
The server will start on `http://localhost:8000`.

---

## 📱 Step 3: Frontend Setup

### 1. Install Dependencies
```bash
cd ../frontend
flutter pub get
```

### 2. Run the App
To run the web version and connect it to your local backend:
```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8000/api/v1
```

---

## 📂 Project Structure

- `backend/`: Node.js + Express API.
- `frontend/`: Flutter application.
- `backend/prisma/`: Database schema and migrations.
- `backend/uploads/`: Local directory for uploaded images (created automatically).

---

## 🛠️ Common Tasks

- **Updating the Schema:** Modify `backend/prisma/schema.prisma` and run `npx prisma db push`.
- **LAN Sharing:** See [LAN_SETUP.md](./LAN_SETUP.md) if you want to host the app for others in your office.

---

## 🔑 Default Credentials

After running `node seed.js`, you can use these accounts:

- **Admin Account:** `admin@gmail.com` / `admin`
- **Reviewer Account:** `reviewer@gmail.com` / `admin`
