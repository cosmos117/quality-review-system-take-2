// ─────────────────────────────────────────────────────────────────────────────
// API Configuration
// ─────────────────────────────────────────────────────────────────────────────
//
// HOW TO USE (LAN Deployment):
//
//   1. Find your PC's Local IP:  Run  ipconfig  in CMD.
//      Look for "IPv4 Address"  e.g.  192.168.1.45
//
//   2. Run Flutter with your LAN IP injected at runtime (no code change needed):
//
//      flutter run -d chrome \
//        --dart-define=API_URL=http://192.168.1.45:8000/api/v1
//
//   3. Your colleagues open the web app in their browser using YOUR IP as the
//      Flutter host.  All API calls automatically go to 192.168.1.45:8000.
//
// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  // Default fallback: your own machine (used when no --dart-define is given)
  static const String _defaultUrl = 'http://localhost:8000/api/v1';

  // The active URL:  overridden at build/run time via --dart-define=API_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultUrl,
  );

  // Checklist endpoints share the same base
  static const String checklistBaseUrl = baseUrl;
}
