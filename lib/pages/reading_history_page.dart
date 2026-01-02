import 'package:flutter/material.dart';

class ReadingHistoryPage extends StatelessWidget {
  final List<Map<String, double>> readingHistory;
  final List<Map<String, dynamic>>? readingHistoryWithTime;

  const ReadingHistoryPage({
    super.key,
    required this.readingHistory,
    this.readingHistoryWithTime,
  });

  String _formatReading(double value, int decimals) {
    return value.toStringAsFixed(decimals);
  }

  String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String parameter, double value) {
    switch (parameter) {
      case 'pH':
        if (value >= 6.5 && value <= 8.5) return Colors.green;
        return Colors.red;
      case 'turbidity':
        if (value < 5) return Colors.green;
        return Colors.red;
      case 'temperature':
        if (value < 25) return Colors.green;
        return Colors.red;
      case 'chlorine':
        if (value >= 0.2 && value <= 2.5) return Colors.green;
        return Colors.red;
      case 'tds':
        if (value < 500) return Colors.green;
        return Colors.red;
      case 'dissolvedOxygen':
        if (value > 5) return Colors.green;
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading History'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: readingHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Reading History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Readings will appear here as they are collected',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: readingHistory.length,
              itemBuilder: (context, index) {
                final reading = readingHistory[index];
                DateTime? timestamp;
                
                // Try to get timestamp from readingHistoryWithTime
                if (readingHistoryWithTime != null && index < readingHistoryWithTime!.length) {
                  final readingWithTime = readingHistoryWithTime![index];
                  final timestampValue = readingWithTime['timestamp'];
                  if (timestampValue is DateTime) {
                    timestamp = timestampValue;
                  }
                }
                
                final timestampText = timestamp != null 
                    ? _formatTimestamp(timestamp)
                    : 'Unknown time';
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      timestampText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'pH: ${_formatReading(reading['pH']!, 2)} • Temp: ${_formatReading(reading['temperature']!, 1)}°C',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.show_chart,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHistoryReadingRow(
                              'pH Level',
                              _formatReading(reading['pH']!, 2),
                              '',
                              _getStatusColor('pH', reading['pH']!),
                              'Safe: 6.5 - 8.5',
                            ),
                            const Divider(height: 16),
                            _buildHistoryReadingRow(
                              'Turbidity',
                              _formatReading(reading['turbidity']!, 2),
                              'NTU',
                              _getStatusColor('turbidity', reading['turbidity']!),
                              'Safe: < 5',
                            ),
                            const Divider(height: 16),
                            _buildHistoryReadingRow(
                              'Temperature',
                              _formatReading(reading['temperature']!, 1),
                              '°C',
                              _getStatusColor('temperature', reading['temperature']!),
                              'Safe: < 25°C',
                            ),
                            const Divider(height: 16),
                            _buildHistoryReadingRow(
                              'Chlorine',
                              _formatReading(reading['chlorine']!, 2),
                              'mg/L',
                              _getStatusColor('chlorine', reading['chlorine']!),
                              'Safe: 0.2 - 2.5',
                            ),
                            const Divider(height: 16),
                            _buildHistoryReadingRow(
                              'Dissolved Oxygen',
                              _formatReading(reading['dissolvedOxygen'] ?? 0, 2),
                              'mg/L',
                              _getStatusColor('dissolvedOxygen', reading['dissolvedOxygen'] ?? 0),
                              'Safe: > 5',
                            ),
                            const Divider(height: 16),
                            _buildHistoryReadingRow(
                              'TDS',
                              _formatReading(reading['tds']!, 0),
                              'mg/L',
                              _getStatusColor('tds', reading['tds']!),
                              'Safe: < 500',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHistoryReadingRow(
    String parameter,
    String value,
    String unit,
    Color statusColor,
    String standard,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parameter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              standard,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusColor == Colors.green ? 'Safe' : 'Unsafe',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
