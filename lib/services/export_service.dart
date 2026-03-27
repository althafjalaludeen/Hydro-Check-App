import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/firebase_water_reading_service.dart';
import '../models/ticket_model.dart';
import '../models/device_model.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();

  factory ExportService() {
    return _instance;
  }

  ExportService._internal();

  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Try to get the root Downloads folder directly
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }
      
      // Fallback to app-specific external downloads if root is unavailable
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        return dirs.first;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Export consolidated water readings to CSV
  Future<File> exportConsolidatedReadingsToCsv({
    required Map<Device, List<WaterReading>> data,
  }) async {
    try {
      final List<List<dynamic>> csvData = [];
      
      // Headers
      csvData.add([
        'Device Name',
        'Device ID',
        'Timestamp',
        'pH',
        'Temperature (°C)',
        'TDS (ppm)',
        'Is Safe',
      ]);

      for (var entry in data.entries) {
        final device = entry.key;
        for (var r in entry.value) {
          csvData.add([
            device.deviceName,
            device.deviceId,
            _dateFormat.format(r.timestamp),
            r.parameters['pH']?.toStringAsFixed(2) ?? '',
            r.parameters['temperature']?.toStringAsFixed(1) ?? '',
            r.parameters['tds']?.toStringAsFixed(0) ?? '',
            r.isSafe ? 'Yes' : 'No',
          ]);
        }
      }

      final csv = const ListToCsvConverter().convert(csvData);

      final dir = await _getDownloadDirectory();
      final file = File('${dir.path}/consolidated_readings_${_fileDateFormat.format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      await shareFile(file);
      return file;
    } catch (e) {
      print('❌ Error exporting consolidated CSV: $e');
      rethrow;
    }
  }

  /// Export water readings to CSV
  Future<File> exportReadingsToCsv({
    required String deviceId,
    required List<WaterReading> readings,
  }) async {
    try {
      final headers = [
        'Reading ID',
        'Device ID',
        'Timestamp',
        'pH',
        'Temperature (°C)',
        'TDS (ppm)',
        'Is Safe',
      ];

      final rows = readings.map((r) => [
            r.readingId,
            r.deviceId,
            _dateFormat.format(r.timestamp),
            r.parameters['pH']?.toStringAsFixed(2) ?? '',
            r.parameters['temperature']?.toStringAsFixed(1) ?? '',
            r.parameters['tds']?.toStringAsFixed(0) ?? '',
            r.isSafe ? 'Yes' : 'No',
          ]);

      final csv = const ListToCsvConverter()
          .convert([headers, ...rows]);

      final dir = await _getDownloadDirectory();
      final file = File(
          '${dir.path}/readings_${deviceId}_${_fileDateFormat.format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      print('✅ CSV exported: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting CSV: $e');
      rethrow;
    }
  }

  /// Export consolidated water readings to PDF (Grouped by device)
  Future<File> exportConsolidatedReadingsToPdf({
    required Map<Device, List<WaterReading>> data,
  }) async {
    try {
      final pdf = pw.Document();

      for (var entry in data.entries) {
        final device = entry.key;
        final readings = entry.value;

        if (readings.isEmpty) continue;

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Water Quality Report - ${device.deviceName}',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
              ],
            ),
            build: (context) => [
              pw.SizedBox(height: 8),
              pw.Text('Device ID: ${device.deviceId}'),
              pw.Text('Location: ${device.location.building} - ${device.location.room}'),
              pw.Text('Generated: ${_dateFormat.format(DateTime.now())}'),
              pw.Text('Total Readings: ${readings.length}'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
                headers: ['Timestamp', 'pH', 'Temp (°C)', 'TDS', 'Safe'],
                data: readings
                    .map((r) => [
                          _dateFormat.format(r.timestamp),
                          r.parameters['pH']?.toStringAsFixed(2) ?? '-',
                          r.parameters['temperature']?.toStringAsFixed(1) ?? '-',
                          r.parameters['tds']?.toStringAsFixed(0) ?? '-',
                          r.isSafe ? '✓' : '✗',
                        ])
                    .toList(),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 20),
                child: pw.Header(level: 1, text: 'Summary: ${device.deviceName}'),
              ),
              _buildSummaryRow('Average pH', _calculateAverage(readings, 'pH')),
              _buildSummaryRow('Average Temperature', '${_calculateAverage(readings, 'temperature')} °C'),
              _buildSummaryRow('Average TDS', '${_calculateAverage(readings, 'tds')} ppm'),
              _buildSummaryRow('Safe Readings', '${readings.where((r) => r.isSafe).length}/${readings.length}'),
            ],
          ),
        );
      }

      final dir = await _getDownloadDirectory();
      final filename = 'consolidated_report_${_fileDateFormat.format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      // Show share sheet (Best for emulator)
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: filename,
      );

      return file;
    } catch (e) {
      print('❌ Error exporting consolidated PDF: $e');
      rethrow;
    }
  }

  /// Export water readings to PDF
  Future<File> exportReadingsToPdf({
    required String deviceId,
    required String deviceName,
    required List<WaterReading> readings,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Water Quality Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Device: $deviceName ($deviceId)'),
            pw.Text(
                'Generated: ${_dateFormat.format(DateTime.now())}'),
            pw.Text('Total Readings: ${readings.length}'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headers: ['Timestamp', 'pH', 'Temp (°C)', 'TDS', 'Safe'],
              data: readings
                  .map((r) => [
                        _dateFormat.format(r.timestamp),
                        r.parameters['pH']?.toStringAsFixed(2) ?? '-',
                        r.parameters['temperature']?.toStringAsFixed(1) ??
                            '-',
                        r.parameters['tds']?.toStringAsFixed(0) ?? '-',
                        r.isSafe ? '✓' : '✗',
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            // Summary section
            pw.Header(level: 1, text: 'Summary'),
            if (readings.isNotEmpty) ...[
              _buildSummaryRow('Average pH',
                  _calculateAverage(readings, 'pH')),
              _buildSummaryRow('Average Temperature',
                  '${_calculateAverage(readings, 'temperature')} °C'),
              _buildSummaryRow('Average TDS',
                  '${_calculateAverage(readings, 'tds')} ppm'),
              _buildSummaryRow('Safe Readings',
                  '${readings.where((r) => r.isSafe).length}/${readings.length}'),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'report_${deviceId}_${_fileDateFormat.format(DateTime.now())}.pdf',
      );

      final dir = await getTemporaryDirectory(); // Use temp for the interim file
      final file = File(
          '${dir.path}/report_${deviceId}_${_fileDateFormat.format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      print('❌ Error exporting PDF: $e');
      rethrow;
    }
  }

  /// Export tickets to CSV
  Future<File> exportTicketsToCsv(List<Ticket> tickets) async {
    try {
      final headers = [
        'Ticket ID',
        'Reporter',
        'Category',
        'Subject',
        'Status',
        'Priority',
        'Created At',
        'Resolved At',
        'Responses',
      ];

      final rows = tickets.map((t) => [
            t.ticketId,
            t.reporterName,
            t.categoryDisplayName,
            t.subject,
            t.statusDisplayName,
            t.priority,
            _dateFormat.format(t.createdAt),
            t.resolvedAt != null
                ? _dateFormat.format(t.resolvedAt!)
                : '',
            t.responses.length.toString(),
          ]);

      final csv = const ListToCsvConverter()
          .convert([headers, ...rows]);

      final dir = await _getDownloadDirectory();
      final file = File(
          '${dir.path}/tickets_${_fileDateFormat.format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      print('✅ Tickets CSV exported: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting tickets CSV: $e');
      rethrow;
    }
  }

  /// Export device list to CSV
  Future<File> exportDeviceListToCsv(List<Device> devices) async {
    try {
      final headers = [
        'Device ID',
        'Device Name',
        'Serial Number',
        'Type',
        'Status',
        'Location',
        'Last Reading',
      ];

      final rows = devices.map((d) => [
            d.deviceId,
            d.deviceName,
            d.serialNumber,
            d.deviceType,
            d.status.displayName,

            '${d.location.building} - Floor ${d.location.floor}',
            d.lastReadingTime != null
                ? _dateFormat.format(d.lastReadingTime!)
                : 'Never',
          ]);

      final csv = const ListToCsvConverter()
          .convert([headers, ...rows]);

      final dir = await _getDownloadDirectory();
      final file = File(
          '${dir.path}/devices_${_fileDateFormat.format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      print('✅ Devices CSV exported: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error exporting devices CSV: $e');
      rethrow;
    }
  }

  /// Share an exported file
  Future<void> shareFile(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      print('❌ Error sharing file: $e');
      rethrow;
    }
  }

  /// Helper: Calculate average for a parameter
  String _calculateAverage(List<WaterReading> readings, String param) {
    final values = readings
        .where((r) => r.parameters.containsKey(param))
        .map((r) => r.parameters[param]!)
        .toList();

    if (values.isEmpty) return '-';
    final avg = values.reduce((a, b) => a + b) / values.length;
    return avg.toStringAsFixed(2);
  }

  /// Helper: Build PDF summary row
  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
