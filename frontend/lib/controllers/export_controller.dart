import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/excel_export_service.dart';
import '../services/master_excel_export_service.dart';

class ExportController extends GetxController {
  final ExcelExportService excelExportService;
  final MasterExcelExportService masterExcelExportService;

  final isExporting = false.obs;
  final exportError = RxnString();

  ExportController({
    required this.excelExportService,
    required this.masterExcelExportService,
  });

  /// Export project to Excel and save to device
  Future<bool> exportProjectToExcel(
    String projectId,
    String projectName, {
    List<String> executors = const [],
    List<String> reviewers = const [],
  }) async {
    try {
      isExporting.value = true;
      exportError.value = null;

      print('🚀 Starting export for project: $projectName');

      // Generate Excel file bytes
      final excelBytesList = await excelExportService.exportProjectToExcel(
        projectId,
        executors: executors,
        reviewers: reviewers,
      );

      // Convert to Uint8List
      final excelBytes = Uint8List.fromList(excelBytesList);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${projectName}_Export_$timestamp.xlsx';

      // Web-only download
      _downloadFileWeb(excelBytes, filename);

      Get.snackbar(
        'Success',
        'Excel file exported successfully!\n$filename',
        duration: const Duration(seconds: 2),
      );

      isExporting.value = false;
      return true;
    } catch (e, stackTrace) {
      print('❌ Export error: $e');
      print('Stack trace: $stackTrace');
      exportError.value = 'Export failed: $e';
      Get.snackbar(
        'Export Failed',
        'Error: $e',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isExporting.value = false;
      return false;
    }
  }

  /// Export all projects as master Excel file
  Future<bool> exportMasterExcel() async {
    try {
      isExporting.value = true;
      exportError.value = null;

      print('🚀 Starting master Excel export for all projects...');

      // Download master Excel from backend
      final fileBytes = await masterExcelExportService.downloadMasterExcel();

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final filename =
          'master_export_${timestamp}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Web-only download
      _downloadFileWeb(Uint8List.fromList(fileBytes), filename);

      Get.snackbar(
        'Success',
        'Master Excel exported successfully!\n$filename',
        duration: const Duration(seconds: 2),
      );

      isExporting.value = false;
      return true;
    } catch (e, stackTrace) {
      print('❌ Master export error: $e');
      print('Stack trace: $stackTrace');
      exportError.value = 'Master export failed: $e';
      Get.snackbar(
        'Master Export Failed',
        'Error: $e',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isExporting.value = false;
      return false;
    }
  }

  /// Download file on web
  void _downloadFileWeb(Uint8List bytes, String filename) {
    try {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement()
        ..href = url
        ..download = filename
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();

      html.Url.revokeObjectUrl(url);
      anchor.remove();

      print('✓ Web file downloaded');
    } catch (e) {
      print('❌ Web download error: $e');
      throw Exception('Web download failed: $e');
    }
  }
}
