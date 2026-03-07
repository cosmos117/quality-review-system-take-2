class ApiConfig {
  static const String _defaultUrl = 'http://localhost:8000/api/v1';
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultUrl,
  );
  // Checklist endpoints (stage-based API)
  static const String checklistBaseUrl = baseUrl;
}
