// Admin Device Details Page - Real-Time Sensor Details with Offline Handling
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../models/device_model.dart';
import '../services/firebase_water_reading_service.dart';
import 'parameter_detail_page.dart';
import 'reading_history_page.dart';

class AdminDeviceDetailsPage extends StatefulWidget {
  final Device device;

  const AdminDeviceDetailsPage({
    super.key,
    required this.device,
  });

  @override
  State<AdminDeviceDetailsPage> createState() => _AdminDeviceDetailsPageState();
}

class _AdminDeviceDetailsPageState extends State<AdminDeviceDetailsPage> {
  final _readingService = FirebaseWaterReadingService();
  
  // Reading history for graph
  final List<Map<String, double>> _readingHistory = [];
  Map<String, double>? _currentReading;
  StreamSubscription? _readingSubscription;
  Timer? _freshnessTimer;
  bool _deviceOnline = false;
  
  // Reading history with timestamps
  final List<Map<String, dynamic>> _readingHistoryWithTime = [];

  @override
  void initState() {
    super.initState();
    _startReadingUpdates();
    _startFreshnessTimer();
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _freshnessTimer?.cancel();
    super.dispose();
  }

  void _startFreshnessTimer() {
    _freshnessTimer?.cancel();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_readingHistoryWithTime.isNotEmpty) {
        final lastTimestamp = _readingHistoryWithTime.last['timestamp'] as DateTime;
        final age = DateTime.now().difference(lastTimestamp);
        
        if (age.inSeconds > 60) {
          if (mounted && _deviceOnline) {
            setState(() => _deviceOnline = false);
          }
        }
      } else if (mounted && _deviceOnline) {
        setState(() => _deviceOnline = false);
      }
    });
  }

  void _startReadingUpdates() {
    _readingSubscription?.cancel();
    _readingSubscription = _readingService
        .getReadingStream(widget.device.deviceId)
        .listen((readings) {
      if (mounted && readings.isNotEmpty) {
        final reading = readings.first;
        final age = DateTime.now().difference(reading.timestamp);
        final bool isFresh = age.inSeconds < 60;

        setState(() {
          _deviceOnline = isFresh;
          _currentReading = reading.parameters;

          // Update history
          _readingHistory.add(_currentReading!);
          if (_readingHistory.length > 20) _readingHistory.removeAt(0);

          _readingHistoryWithTime.add({
            'timestamp': reading.timestamp,
            ...reading.parameters,
          });
          if (_readingHistoryWithTime.length > 20) _readingHistoryWithTime.removeAt(0);
        });
      }
    });
  }

  Color _getParameterColor(String parameter, double value) {
    if (!_deviceOnline) return Colors.grey;
    switch (parameter) {
      case 'pH':
        return (value >= 6.5 && value <= 8.5) ? Colors.green : Colors.red;
      case 'temperature':
        return (value < 25) ? Colors.green : Colors.red;
      case 'tds':
        return (value < 500) ? Colors.green : Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getParameterStatus(String parameter, double value) {
    if (!_deviceOnline) return 'OFFLINE';
    final color = _getParameterColor(parameter, value);
    return color == Colors.green ? 'SAFE' : 'UNSAFE';
  }

  Widget _buildReadingsTrendChart(String parameter, String label, Color lineColor, List<double> safeThresholds) {
    final spots = <FlSpot>[];
    for (int i = 0; i < _readingHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), _readingHistory[i][parameter] ?? 0));
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Opacity(
        opacity: _deviceOnline ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: lineColor, size: 20),
                  const SizedBox(width: 8),
                  Text('$label Trend', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: lineColor,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.2)),
                      ),
                      for (var threshold in safeThresholds)
                        LineChartBarData(
                          spots: List.generate(spots.length, (i) => FlSpot(i.toDouble(), threshold)),
                          isCurved: false,
                          color: Colors.orange.withValues(alpha: 0.3),
                          barWidth: 1,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterCard(String name, String value, String unit, String parameterKey) {
    final double numValue = double.tryParse(value) ?? 0;
    final color = _getParameterColor(parameterKey, numValue);
    final status = _getParameterStatus(parameterKey, numValue);
    
    return GestureDetector(
      onTap: () {
        if (!_deviceOnline) return;
        late String description;
        late double minSafe;
        late double maxSafe;
        late IconData icon;

        switch (parameterKey) {
          case 'pH':
            icon = Icons.analytics;
            description = 'pH Level. Safe: 6.5 - 8.5.';
            minSafe = 6.5; maxSafe = 8.5;
            break;
          case 'temperature':
            icon = Icons.thermostat;
            description = 'Temperature. Safe: < 25°C.';
            minSafe = 0; maxSafe = 25;
            break;
          case 'tds':
            icon = Icons.water;
            description = 'TDS. Safe: < 500 mg/L.';
            minSafe = 0; maxSafe = 500;
            break;
          default: return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParameterDetailPage(
              parameterName: name,
              currentValue: numValue,
              unit: unit,
              description: description,
              minSafe: minSafe,
              maxSafe: maxSafe,
              color: color,
              icon: icon,
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Opacity(
          opacity: _deviceOnline ? 1.0 : 0.7,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$value $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pH = _currentReading?['pH'] ?? 0;
    final temperature = _currentReading?['temperature'] ?? 0;
    final tds = _currentReading?['tds'] ?? 0;

    final allSafe = _deviceOnline && _currentReading != null &&
        pH >= 6.5 && pH <= 8.5 &&
        temperature < 25 &&
        tds < 500;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.deviceName),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.device.deviceName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${widget.device.location.building} • Floor ${widget.device.location.floor}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            // Status Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _deviceOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _deviceOnline ? Colors.green : Colors.red),
              ),
              child: Row(
                children: [
                  Icon(_deviceOnline ? Icons.online_prediction : Icons.cloud_off, color: _deviceOnline ? Colors.green : Colors.red),
                  const SizedBox(width: 12),
                  Text(
                    _deviceOnline ? 'Device Online' : 'Device Offline / No Recent Data',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _deviceOnline ? Colors.green[800] : Colors.red[800]),
                  ),
                ],
              ),
            ),

            // Safety Banner (Only if online)
            if (_deviceOnline && _currentReading != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: allSafe ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: allSafe ? Colors.green : Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(allSafe ? Icons.check_circle : Icons.warning, color: allSafe ? Colors.green : Colors.orange, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(allSafe ? 'WATER IS SAFE' : 'CAUTION ADVISED', style: TextStyle(fontWeight: FontWeight.bold, color: allSafe ? Colors.green[800] : Colors.orange[800])),
                          Text(allSafe ? 'All parameters within safe limits.' : 'Some parameters exceed safe levels.', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Parameter Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildParameterCard('pH Level', pH.toStringAsFixed(2), '', 'pH')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildParameterCard('Temperature', temperature.toStringAsFixed(1), '°C', 'temperature')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildParameterCard('Total Dissolved Solids', tds.toStringAsFixed(0), 'mg/L', 'tds'),
                ],
              ),
            ),

            // Charts
            _buildReadingsTrendChart('pH', 'pH Level', const Color(0xFF3B82F6), [6.5, 8.5]),
            _buildReadingsTrendChart('temperature', 'Temperature', const Color(0xFFEF4444), [25]),
            _buildReadingsTrendChart('tds', 'TDS', const Color(0xFFA855F7), [500]),

            // History Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReadingHistoryPage(
                          readingHistory: _readingHistory,
                          readingHistoryWithTime: _readingHistoryWithTime,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View Full History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
