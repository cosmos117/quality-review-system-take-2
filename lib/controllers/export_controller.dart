import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/excel_export_service.dart';
import '../services/master_excel_export_service.dart';

// Conditional web imports
import 'dart:html' as html;

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

      // Try web download first
      try {
        _downloadFileWeb(excelBytes, filename);
      } catch (webError) {
        await _downloadFileNative(excelBytes, filename);
      }

      Get.snackbar(
        'Success',
        'Excel file exported successfully!\n$filename',
        duration: const Duration(seconds: 4),
      );

      isExporting.value = false;
      return true;
    } catch (e, _) {
      exportError.value = 'Export failed: $e';
      Get.snackbar(
        'Export Failed',
        'Error: $e',
        duration: const Duration(seconds: 3),
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
      // Download master Excel from backend
      final fileBytes = await masterExcelExportService.downloadMasterExcel();

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final filename =
          'master_export_${timestamp}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Try web download first
      try {
        _downloadFileWeb(Uint8List.fromList(fileBytes), filename);
      } catch (webError) {
        await _downloadFileNative(Uint8List.fromList(fileBytes), filename);
      }

      Get.snackbar(
        'Success',
        'Master Excel exported successfully!\n$filename',
        duration: const Duration(seconds: 4),
      );

      isExporting.value = false;
      return true;
    } catch (e, _) {
      exportError.value = 'Master export failed: $e';
      Get.snackbar(
        'Master Export Failed',
        'Error: $e',
        duration: const Duration(seconds: 3),
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
    } catch (e) {
      throw Exception('Web download failed: $e');
    }
  }

  /// Download file on native platform
  Future<void> _downloadFileNative(Uint8List bytes, String filename) async {
    try {
      // For desktop platforms
      final downloadsPath = _getDownloadsPath();
      final downloadDir = io.Directory(downloadsPath);

      // Create directory if it doesn't exist
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filepath = '$downloadsPath${io.Platform.pathSeparator}$filename';
      final file = io.File(filepath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      throw Exception('Native download failed: $e');
    }
  }

  /// Get Downloads folder path
  String _getDownloadsPath() {
    try {
      if (io.Platform.isWindows) {
        final userProfile = io.Platform.environment['USERPROFILE'] ?? '';
        return '$userProfile\\Downloads';
      } else if (io.Platform.isMacOS) {
        final home = io.Platform.environment['HOME'] ?? '';
        return '$home/Downloads';
      } else if (io.Platform.isLinux) {
        final home = io.Platform.environment['HOME'] ?? '';
        return '$home/Downloads';
      }
    } catch (e) {}
    return '/tmp';
  }
}
