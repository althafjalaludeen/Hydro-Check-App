import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/export_service.dart';
import '../services/firebase_water_reading_service.dart';

class TestHistoryPage extends StatelessWidget {
  final String deviceId;

  const TestHistoryPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test History'),
        centerTitle: true,
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download PDF Report',
            onPressed: () => _downloadPdfReport(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .collection('test_results')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No test results yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Tap "Test Now" on the dashboard to run a test.',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final ph = (data['pH'] as num?)?.toDouble() ?? 0;
              final temp = (data['temperature'] as num?)?.toDouble() ?? 0;
              final tds = (data['tds'] as num?)?.toDouble() ?? 0;
              final isSafe = data['isSafe'] as bool? ?? true;
              final samples = data['samples'] as int? ?? 0;
              final timestamp = data['timestamp'] is Timestamp
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              return _buildTestCard(
                  context, ph, temp, tds, isSafe, samples, timestamp);
            },
          );
        },
      ),
    );
  }

  Future<void> _downloadPdfReport(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF Report...'), duration: Duration(seconds: 1)),
      );

      // Fetch latest 50 results
      final snapshot = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No test results to export')),
          );
        }
        return;
      }

      // Convert to WaterReading format
      final readings = snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();

        return WaterReading(
          readingId: doc.id,
          deviceId: deviceId,
          timestamp: timestamp,
          parameters: {
            'pH': (data['pH'] as num?)?.toDouble() ?? 0,
            'temperature': (data['temperature'] as num?)?.toDouble() ?? 0,
            'tds': (data['tds'] as num?)?.toDouble() ?? 0,
          },
          isSafe: data['isSafe'] as bool? ?? true,
          alertsGenerated: false,
        );
      }).toList();

      // Export to PDF
      final file = await ExportService().exportReadingsToPdf(
        deviceId: deviceId,
        deviceName: 'Device $deviceId', // You might want to pass the actual name if available
        readings: readings,
      );

      // Share/Save the file
      await ExportService().shareFile(file);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Widget _buildTestCard(BuildContext context, double ph, double temp,
      double tds, bool isSafe, int samples, DateTime timestamp) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final dateStr =
        '${months[timestamp.month - 1]} ${timestamp.day.toString().padLeft(2, '0')}, ${timestamp.year}';
    final hour = timestamp.hour > 12
        ? timestamp.hour - 12
        : (timestamp.hour == 0 ? 12 : timestamp.hour);
    final amPm = timestamp.hour >= 12 ? 'PM' : 'AM';
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} $amPm';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date + Safety Badge
            Row(
              children: [
                const Icon(Icons.science, color: Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 8),
                Text(dateStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 6),
                Text(timeStr,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSafe ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isSafe ? Colors.green.shade300 : Colors.red.shade300,
                    ),
                  ),
                  child: Text(
                    isSafe ? 'Safe' : 'Unsafe',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          isSafe ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Readings Row
            Row(
              children: [
                _readingChip(Icons.analytics, 'pH', ph.toStringAsFixed(2),
                    ph >= 6.5 && ph <= 8.5),
                const SizedBox(width: 8),
                _readingChip(Icons.thermostat, 'Temp',
                    '${temp.toStringAsFixed(1)}°C', temp < 32),
                const SizedBox(width: 8),
                _readingChip(Icons.water, 'TDS',
                    '${tds.toStringAsFixed(0)} ppm', tds < 500),
              ],
            ),

            const SizedBox(height: 8),
            Text('$samples samples averaged',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _readingChip(IconData icon, String label, String value, bool safe) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: safe ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: safe ? Colors.green : Colors.red),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: safe ? Colors.green.shade700 : Colors.red.shade700)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
