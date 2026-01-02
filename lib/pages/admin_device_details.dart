// Admin Device Details Page - Full Sensor Details with Graphs and History
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import '../models/device_model.dart';
import '../services/water_quality_alert_service.dart';
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
  // Reading history for graph
  final List<Map<String, double>> _readingHistory = [];
  Map<String, double>? _currentReading;
  Timer? _updateTimer;
  
  // Reading history with timestamps
  final List<Map<String, dynamic>> _readingHistoryWithTime = [];

  @override
  void initState() {
    super.initState();
    _startReadingUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startReadingUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentReading = _generateDeviceReading();
          final now = DateTime.now();
          _readingHistory.add(_currentReading!);
          // Add reading with timestamp synced to phone's system time
          _readingHistoryWithTime.add({
            'timestamp': now,
            'pH': _currentReading!['pH'],
            'turbidity': _currentReading!['turbidity'],
            'temperature': _currentReading!['temperature'],
            'chlorine': _currentReading!['chlorine'],
            'tds': _currentReading!['tds'],
            'dissolvedOxygen': _currentReading!['dissolvedOxygen'],
          });
          // Keep only last 20 readings for the graph
          if (_readingHistory.length > 20) {
            _readingHistory.removeAt(0);
            _readingHistoryWithTime.removeAt(0);
          }
          
          // Check water quality and show alert if unsafe
          final unsafeAlerts = WaterQualityChecker.getUnsafeAlerts(_currentReading!);
          if (unsafeAlerts.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              WaterQualityChecker.showWaterQualityAlert(context, unsafeAlerts);
            });
          }
        });
      }
    });
    // Generate initial reading
    setState(() {
      _currentReading = _generateDeviceReading();
      final now = DateTime.now();
      _readingHistory.add(_currentReading!);
      // Add initial reading with timestamp synced to phone's system time
      _readingHistoryWithTime.add({
        'timestamp': now,
        'pH': _currentReading!['pH'],
        'turbidity': _currentReading!['turbidity'],
        'temperature': _currentReading!['temperature'],
        'chlorine': _currentReading!['chlorine'],
        'tds': _currentReading!['tds'],
        'dissolvedOxygen': _currentReading!['dissolvedOxygen'],
      });
      
      // Check water quality and show alert if unsafe
      final unsafeAlerts = WaterQualityChecker.getUnsafeAlerts(_currentReading!);
      if (unsafeAlerts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WaterQualityChecker.showWaterQualityAlert(context, unsafeAlerts);
        });
      }
    });
  }

  Map<String, double> _generateDeviceReading() {
    final random = Random();

    // Generate unsafe readings (30% probability)
    final isUnsafe = random.nextInt(100) < 30;

    return {
      'pH': isUnsafe ? random.nextDouble() * 10 : 6.5 + random.nextDouble() * 2,
      'turbidity': isUnsafe ? random.nextDouble() * 10 : random.nextDouble() * 4,
      'temperature': isUnsafe ? 25 + random.nextDouble() * 5 : 20 + random.nextDouble() * 4,
      'chlorine': isUnsafe ? random.nextDouble() * 5 : 0.5 + random.nextDouble() * 1.8,
      'tds': isUnsafe ? 500 + random.nextDouble() * 200 : 200 + random.nextDouble() * 250,
      'dissolvedOxygen': isUnsafe ? 2.0 + random.nextDouble() * 3.0 : 6.0 + random.nextDouble() * 4.0,
    };
  }

  Color _getParameterColor(String parameter, double value) {
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

  String _getParameterStatus(String parameter, double value) {
    final color = _getParameterColor(parameter, value);
    if (color == Colors.green) return 'SAFE';
    if (color == Colors.orange) return 'CAUTION';
    return 'UNSAFE';
  }

  Widget _buildReadingsTrendChart(String parameter, Color lineColor, List<double> safeThresholds) {
    final spots = <FlSpot>[];
    for (int i = 0; i < _readingHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), _readingHistory[i][parameter] ?? 0));
    }

    String safeRangeLabel;
    switch (parameter) {
      case 'pH':
        safeRangeLabel = 'Safe: 6.5 - 8.5';
        break;
      case 'turbidity':
        safeRangeLabel = 'Safe: < 5 NTU';
        break;
      case 'temperature':
        safeRangeLabel = 'Safe: < 25°C';
        break;
      case 'chlorine':
        safeRangeLabel = 'Safe: 0.2 - 2.5 mg/L';
        break;
      case 'tds':
        safeRangeLabel = 'Safe: < 500 mg/L';
        break;
      case 'dissolvedOxygen':
        safeRangeLabel = 'Safe: > 5 mg/L';
        break;
      default:
        safeRangeLabel = '';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: lineColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$parameter Trend',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  safeRangeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.2),
                      ),
                    ),
                    if (safeThresholds.length == 1)
                      LineChartBarData(
                        spots: List.generate(
                          spots.length,
                          (index) => FlSpot(index.toDouble(), safeThresholds[0]),
                        ),
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      )
                    else if (safeThresholds.length == 2) ...[
                      LineChartBarData(
                        spots: List.generate(
                          spots.length,
                          (index) => FlSpot(index.toDouble(), safeThresholds[0]),
                        ),
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: List.generate(
                          spots.length,
                          (index) => FlSpot(index.toDouble(), safeThresholds[1]),
                        ),
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterCard(String name, String value, String unit, String status, Color color) {
    return GestureDetector(
      onTap: () {
        // Get parameter details
        late String description;
        late double minSafe;
        late double maxSafe;
        late IconData icon;

        final numValue = double.tryParse(value) ?? 0;

        switch (name) {
          case 'pH Level':
            icon = Icons.analytics;
            description = 'pH is a measure of acidity or basicity of water. A pH of 7 is neutral, '
                'values below 7 are acidic, and values above 7 are basic (alkaline). '
                'According to WHO standards, drinking water should have a pH between 6.5 and 8.5. '
                'Water outside this range can cause taste issues and may affect water treatment effectiveness.';
            minSafe = 6.5;
            maxSafe = 8.5;
            break;
          case 'Turbidity':
            icon = Icons.blur_on;
            description = 'Turbidity measures the cloudiness or haziness of water caused by suspended particles. '
                'High turbidity can harbor harmful microorganisms and interfere with water treatment. '
                'WHO recommends turbidity should not exceed 5 NTU (Nephelometric Turbidity Units) for drinking water. '
                'Clear water (low turbidity) is generally safer and more aesthetically pleasing.';
            minSafe = 0;
            maxSafe = 5;
            break;
          case 'Temperature':
            icon = Icons.thermostat;
            description = 'Water temperature affects chemical reactions and can influence bacterial growth. '
                'Cold water is generally safer as it slows microbial growth. '
                'WHO recommends drinking water temperature should be below 25°C for optimal safety. '
                'High temperatures can promote bacterial proliferation and chemical reactions that affect water quality.';
            minSafe = 0;
            maxSafe = 25;
            break;
          case 'Chlorine':
            icon = Icons.science;
            description = 'Chlorine is a disinfectant used to kill harmful microorganisms in water. '
                'While beneficial for disinfection, excessive chlorine can affect taste and odor. '
                'WHO recommends free chlorine should be between 0.2-2.5 mg/L for effective disinfection without adverse effects. '
                'Proper chlorination prevents waterborne diseases while maintaining water quality.';
            minSafe = 0.2;
            maxSafe = 2.5;
            break;
          case 'Total Dissolved Solids':
            icon = Icons.water;
            description = 'TDS represents the total amount of dissolved minerals, salts, and other substances in water. '
                'While some minerals are beneficial, high TDS can affect taste and may indicate contamination. '
                'WHO recommends TDS should not exceed 500 mg/L for drinking water. '
                'Very high TDS levels can make water unpalatable and may pose health risks over long-term consumption.';
            minSafe = 0;
            maxSafe = 500;
            break;
          default:
            icon = Icons.info;
            description = 'No description available';
            minSafe = 0;
            maxSafe = 100;
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$value $unit',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentReading == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Details'),
          backgroundColor: const Color(0xFF0F172A),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pH = _currentReading!['pH'] ?? 0;
    final turbidity = _currentReading!['turbidity'] ?? 0;
    final temperature = _currentReading!['temperature'] ?? 0;
    final chlorine = _currentReading!['chlorine'] ?? 0;
    final tds = _currentReading!['tds'] ?? 0;
    final dissolvedOxygen = _currentReading!['dissolvedOxygen'] ?? 0;

    final allSafe = pH >= 6.5 && pH <= 8.5 &&
        turbidity < 5 &&
        temperature < 25 &&
        chlorine >= 0.2 && chlorine <= 2.5 &&
        tds < 500 &&
        dissolvedOxygen > 5;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.deviceName),
        centerTitle: true,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Device Info Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.deviceName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.device.location.building} • Floor ${widget.device.location.floor} • Room ${widget.device.location.room}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  // GPS Location Display
                  if (widget.device.location.latitude != null && widget.device.location.longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'GPS: ${widget.device.location.latitude!.toStringAsFixed(4)}, ${widget.device.location.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Water Safety Status
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: allSafe ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: allSafe ? Colors.green.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.05),
              ),
              child: Column(
                children: [
                  Icon(
                    allSafe ? Icons.check_circle : Icons.warning,
                    size: 40,
                    color: allSafe ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Water Safety Status',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    allSafe ? 'SAFE' : 'CAUTION',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: allSafe ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    allSafe
                        ? 'All parameters within safe ranges.'
                        : 'Some parameters are outside safe ranges. Recommend testing before consumption.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Live Readings
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Color(0xFF3B82F6), size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Live Readings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.fiber_manual_record, size: 8, color: Colors.green),
                            SizedBox(width: 6),
                            Text(
                              'Live',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildParameterCard(
                        'pH Level',
                        pH.toStringAsFixed(2),
                        '',
                        _getParameterStatus('pH', pH),
                        _getParameterColor('pH', pH),
                      ),
                      _buildParameterCard(
                        'Turbidity',
                        turbidity.toStringAsFixed(2),
                        'NTU',
                        _getParameterStatus('turbidity', turbidity),
                        _getParameterColor('turbidity', turbidity),
                      ),
                      _buildParameterCard(
                        'Temperature',
                        temperature.toStringAsFixed(1),
                        '°C',
                        _getParameterStatus('temperature', temperature),
                        _getParameterColor('temperature', temperature),
                      ),
                      _buildParameterCard(
                        'Chlorine',
                        chlorine.toStringAsFixed(2),
                        'mg/L',
                        _getParameterStatus('chlorine', chlorine),
                        _getParameterColor('chlorine', chlorine),
                      ),
                      _buildParameterCard(
                        'Dissolved Oxygen',
                        dissolvedOxygen.toStringAsFixed(2),
                        'mg/L',
                        _getParameterStatus('dissolvedOxygen', dissolvedOxygen),
                        _getParameterColor('dissolvedOxygen', dissolvedOxygen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildParameterCard(
                    'Total Dissolved Solids',
                    tds.toStringAsFixed(0),
                    'mg/L',
                    _getParameterStatus('tds', tds),
                    _getParameterColor('tds', tds),
                  ),
                ],
              ),
            ),

            // Readings Trend Charts
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.show_chart, color: Color(0xFF3B82F6), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Readings Trend',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReadingsTrendChart('pH', const Color(0xFF3B82F6), [6.5, 8.5]),
                  _buildReadingsTrendChart('turbidity', const Color(0xFF06B6D4), [5]),
                  _buildReadingsTrendChart('temperature', const Color(0xFFEF4444), [25]),
                  _buildReadingsTrendChart('chlorine', const Color(0xFF10B981), [0.2, 2.5]),
                  _buildReadingsTrendChart('dissolvedOxygen', const Color(0xFF14B8A6), [5]),
                  _buildReadingsTrendChart('tds', const Color(0xFFA855F7), [500]),
                ],
              ),
            ),

            // View History Button
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
                  label: const Text('View Reading History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
