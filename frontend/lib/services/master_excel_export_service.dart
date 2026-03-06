import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/http_client.dart';

/// Master Excel Export Service
/// Handles downloading the master Excel export from backend
class MasterExcelExportService {
  final SimpleHttp httpClient;

  MasterExcelExportService({required this.httpClient});

  /// Download master Excel file for all projects
  /// Returns file bytes that can be downloaded
  Future<List<int>> downloadMasterExcel() async {
    try {
      print('📥 Downloading master Excel export...');

      final uri = Uri.parse('${ApiConfig.baseUrl}/admin/export/master-excel');

      // Make GET request with auth header
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${httpClient.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 400) {
        throw Exception(
          'Failed to download master Excel: HTTP ${response.statusCode}',
        );
      }

      print('✓ Master Excel downloaded successfully');
      return response.bodyBytes;
    } catch (e) {
      print('❌ Error downloading master Excel: $e');
      rethrow;
    }
  }
}
