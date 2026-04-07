# LAN Deployment Guide
## Quality Review System — Internal Network Setup

This guide explains how to make the app accessible to everyone in your office
on the same Wi-Fi / Ethernet network, without any cloud hosting.

---

## Step 1 — Find Your Server PC's Local IP

On the PC that will run the backend, open **Command Prompt (CMD)** and type:

```
ipconfig
```

Look for **IPv4 Address** under your active network adapter.
Example result: `192.168.1.45`

---

## Step 2 — Start the Backend

```bash
cd backend
npm run dev
```

The server now listens on `0.0.0.0:8000`, meaning it accepts connections from
ALL devices on the same network, not just from localhost.

You will see this in the terminal:
```
Server is running on http://0.0.0.0:8000
LAN Access: http://<YOUR_LOCAL_IP>:8000
Run 'ipconfig' in CMD to find your Local IPv4 Address
```

---

## Step 3 — Open the Windows Firewall Port

By default Windows blocks incoming connections. Allow port 8000:

1. Search → **"Windows Defender Firewall with Advanced Security"**
2. Click **Inbound Rules** → **New Rule**
3. Choose **Port** → **TCP** → Specific port: `8000`
4. Choose **Allow the connection**
5. Check **Domain**, **Private**, **Public**
6. Name it: `Checklist Backend`

> **Note:** You must also allow port `5173` (or whichever port Flutter Web runs on)
> if your colleagues are accessing the frontend from your machine too.

---

## Step 4 — Run the Flutter Frontend with Your LAN IP

Replace `192.168.1.45` with YOUR actual IPv4 address found in Step 1.

```bash
cd frontend
flutter run -d chrome --dart-define=API_URL=http://192.168.1.45:8000/api/v1
```

The `--dart-define` flag injects your LAN IP at runtime.
**No code changes required** to switch between localhost and LAN — just change the flag.

---

## Step 5 — Share Access with Colleagues

Your colleagues open **their browser** and navigate to:

```
http://192.168.1.45:<FLUTTER_PORT>
```

(The Flutter dev server port is shown in your terminal when you run `flutter run`, usually `5173` or `8080`.)

All their API calls, image uploads, and checklist data go to **your PC** automatically.

---

## How Images Work on LAN

```
Colleague's Browser
      │
      │  POST /api/v1/images/:questionId?role=executor
      ▼
Your PC (192.168.1.45:8000)  ← Node.js Backend
      │
      │  Saves file to:
      ▼
backend/uploads/<uuid>           ← Raw image file
backend/uploads_metadata/<uuid>.json  ← Metadata (who, which question, which role)
      │
      │  Returns fileId to browser
      ▼
ChecklistAnswer saved in MySQL with fileId reference
      │
      │  When YOU open the checklist:
      ▼
GET /api/v1/images/file/<fileId>
      │
      ▼
Your PC streams the image file from backend/uploads/ to your browser
```

**Key point:** Because everyone talks to YOUR PC, the uploads folder on YOUR machine
is the single source of truth. Everyone sees the same images.

---

## Checklist for Going Live

- [ ] Find Local IP via `ipconfig`
- [ ] Start backend: `npm run dev` (keep terminal open)
- [ ] Windows Firewall: Port 8000 allowed (Inbound TCP)
- [ ] Flutter run with `--dart-define=API_URL=http://<YOUR_IP>:8000/api/v1`
- [ ] Colleagues access via `http://<YOUR_IP>:<FLUTTER_PORT>`
- [ ] **Power Settings:** Set PC to Never Sleep while in use

---

## Important Warnings

> **The PC must stay ON** while colleagues are using the app.
> If it sleeps or shuts down, everyone loses access until it restarts.

> **The uploads folder is only on your PC.**
> Back up `backend/uploads/` and `backend/uploads_metadata/` regularly
> to avoid losing checklist photos.
