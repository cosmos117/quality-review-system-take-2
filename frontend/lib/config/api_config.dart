// API base URL configuration.
// Override it at run/build time with:
// --dart-define=API_URL=http://<server-ip>:8000/api/v1

class ApiConfig {
  // Local fallback when API_URL is not provided.
  static const String _defaultUrl = 'http://localhost:8000/api/v1';

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultUrl,
  );

  static const String checklistBaseUrl = baseUrl;
}
