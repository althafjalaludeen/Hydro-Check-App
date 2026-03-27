// User Dashboard - Single Device Monitoring with Robust Offline Handling
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../services/firebase_authentication_service.dart';
import '../services/firebase_device_service.dart';
import '../services/firebase_water_reading_service.dart';
import '../services/export_service.dart';
import '../widgets/device_card_widget.dart';
import 'parameter_detail_page.dart';
import 'add_device_page.dart';
import 'test_history_page.dart';
import 'ticket_pages.dart';
import 'announcements_page.dart';

class UserDashboard extends StatefulWidget {
  final User user;

  const UserDashboard({
    super.key,
    required this.user,
  });

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  late final FirebaseAuthenticationService _authService;
  late final FirebaseDeviceService _deviceService;
  late final FirebaseWaterReadingService _readingService;

  Device? _device;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showDetails = false;
  bool _deviceOnline = false;

  final List<Map<String, double>> _readingHistory = [];
  Map<String, double>? _currentReading;
  StreamSubscription? _readingSubscription;
  Timer? _freshnessTimer;

  final List<Map<String, dynamic>> _readingHistoryWithTime = [];

  bool _isTesting = false;
  int _testSecondsLeft = 15;
  final List<Map<String, double>> _testReadings = [];
  StreamSubscription? _testSubscription;
  Timer? _testTimer;
  String? _lastTestReadingId;

  @override
  void initState() {
    super.initState();
    _authService = FirebaseAuthenticationService();
    _deviceService = FirebaseDeviceService();
    _readingService = FirebaseWaterReadingService();
    _loadDevice();
  }

  @override
  void dispose() {
    _readingSubscription?.cancel();
    _testSubscription?.cancel();
    _testTimer?.cancel();
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
    if (_device == null) return;
    _readingSubscription?.cancel();
    _readingSubscription = _readingService.getReadingStream(_device!.deviceId).listen((readings) {
      if (mounted && readings.isNotEmpty) {
        final reading = readings.first;
        final age = DateTime.now().difference(reading.timestamp);
        final bool isFresh = age.inSeconds < 60;

        setState(() {
          _deviceOnline = isFresh;
          _currentReading = reading.parameters;

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

  Future<void> _loadDevice() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final devices = await _deviceService.getUserDevices(widget.user.uid);
      if (mounted) {
        setState(() {
          _device = devices.isNotEmpty ? devices.first : null;
          _errorMessage = null;
          if (_device != null) {
            _startReadingUpdates();
            _startFreshnessTimer();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load device: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- TEST NOW FEATURE ----
  void _startTestNow() {
    if (_isTesting || _device == null) return;
    setState(() {
      _isTesting = true;
      _testSecondsLeft = 15;
      _testReadings.clear();
      _lastTestReadingId = null;
    });

    _testTimer?.cancel();
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _testSecondsLeft--);
      if (_testSecondsLeft <= 0) {
        timer.cancel();
        _testSubscription?.cancel();
        _finishTest();
      }
    });

    _testSubscription?.cancel();
    _testSubscription = _readingService.getReadingStream(_device!.deviceId).listen((readings) {
      if (!mounted || !_isTesting || readings.isEmpty) return;
      final reading = readings.first;
      if (reading.readingId != _lastTestReadingId) {
        _lastTestReadingId = reading.readingId;
        _testReadings.add(Map<String, double>.from(reading.parameters));
        setState(() {});
      }
    });
  }

  void _finishTest() {
    _testTimer?.cancel();
    _testSubscription?.cancel();
    if (_testReadings.isEmpty) {
      setState(() => _isTesting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No readings received during test.')));
      return;
    }

    final avgResult = <String, double>{};
    final keys = ['pH', 'temperature', 'tds'];
    for (final key in keys) {
      final values = _testReadings.where((r) => r.containsKey(key)).map((r) => r[key]!).toList();
      if (values.isNotEmpty) {
        values.sort();
        avgResult[key] = values[values.length ~/ 2];
      }
    }
    setState(() => _isTesting = false);
    _showTestResults(avgResult);
  }

  void _showTestResults(Map<String, double> results) {
    final ph = results['pH'] ?? 0;
    final temp = results['temperature'] ?? 0;
    final tds = results['tds'] ?? 0;
    final isSafe = ph >= 6.5 && ph <= 8.5 && temp < 32 && tds < 500;

    if (_device != null) {
      FirebaseFirestore.instance.collection('devices').doc(_device!.deviceId).collection('test_results').add({
        'pH': ph, 'temperature': temp, 'tds': tds, 'isSafe': isSafe,
        'samples': _testReadings.length, 'timestamp': FieldValue.serverTimestamp(),
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(isSafe ? Icons.check_circle : Icons.warning, color: isSafe ? Colors.green : Colors.red, size: 28),
          const SizedBox(width: 10),
          Text(isSafe ? 'Water is Safe' : 'Water Unsafe', style: TextStyle(color: isSafe ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Averaged from ${_testReadings.length} samples', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 16),
          _testResultRow(Icons.analytics, 'pH', ph.toStringAsFixed(2), '', ph >= 6.5 && ph <= 8.5),
          const SizedBox(height: 10),
          _testResultRow(Icons.thermostat, 'Temp', temp.toStringAsFixed(1), '°C', temp < 32),
          const SizedBox(height: 10),
          _testResultRow(Icons.water, 'TDS', tds.toStringAsFixed(0), 'ppm', tds < 500),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _testResultRow(IconData icon, String label, String value, String unit, bool safe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: safe ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: safe ? Colors.green.shade200 : Colors.red.shade200)),
      child: Row(children: [
        Icon(icon, color: safe ? Colors.green : Colors.red, size: 22),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$value $unit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: safe ? Colors.green.shade700 : Colors.red.shade700)),
        const SizedBox(width: 6),
        Icon(safe ? Icons.check_circle : Icons.cancel, size: 18, color: safe ? Colors.green : Colors.red),
      ]),
    );
  }

  Future<void> _refreshDevice() async { await _loadDevice(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device status refreshed'))); }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Device'), content: Text('Are you sure you want to delete ${_device?.deviceName}?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    if (confirmed == true && _device != null) {
      try {
        await _deviceService.deleteDevice(_device!.deviceId, widget.user.uid);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device deleted successfully'))); await _loadDevice(); }
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting device: $e'))); }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Logout'), content: const Text('Are you sure you want to logout?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout'))]));
    if (confirmed == true) { await _authService.logout(); if (mounted) Navigator.pushReplacementNamed(context, '/login'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Device'), centerTitle: true, backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white, elevation: 2,
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddDevicePage(user: widget.user))); if (result == true) await _loadDevice(); }, tooltip: 'Add New Device'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDevice, tooltip: 'Refresh'),
          PopupMenuButton<String>(itemBuilder: (context) => [
            PopupMenuItem(value: 'profile', child: const Row(children: [Icon(Icons.person, size: 20), SizedBox(width: 12), Text('Profile')]), onTap: () => _showProfileDialog()),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'report_issue', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTicketPage(currentUser: widget.user))), child: const Row(children: [Icon(Icons.report_problem, size: 20, color: Colors.orange), SizedBox(width: 12), Text('Report Issue')])),
            PopupMenuItem(value: 'my_tickets', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketListPage(currentUser: widget.user))), child: const Row(children: [Icon(Icons.support_agent, size: 20, color: Colors.blue), SizedBox(width: 12), Text('My Tickets')])),
            PopupMenuItem(value: 'announcements', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnnouncementsPage(currentUser: widget.user))), child: const Row(children: [Icon(Icons.campaign, size: 20, color: Colors.purple), SizedBox(width: 12), Text('Announcements')])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'logout', onTap: _logout, child: const Row(children: [Icon(Icons.logout, size: 20, color: Colors.red), SizedBox(width: 12), Text('Logout', style: TextStyle(color: Colors.red))])),
          ]),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome, ${widget.user.fullName}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4), Text('User • ${widget.user.location}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 12),
          if (_device != null) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white30)), child: Row(children: [const Icon(Icons.location_on, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('${_device!.location.building} - Floor ${_device!.location.floor}, ${_device!.location.room}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis))]))
        ])),
        if (_errorMessage != null) Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red.shade300), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.error_outline, color: Colors.red.shade600), const SizedBox(width: 12), Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade600)))])) else if (_device == null) Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.devices_other, size: 100, color: Colors.blue.shade300), const SizedBox(height: 24), const Text('Add Your First Device', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Text('Register your HydroCheck device to start monitoring.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])), const SizedBox(height: 32), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddDevicePage(user: widget.user))); if (result == true) await _loadDevice(); }, icon: const Icon(Icons.add), label: const Text('Add Device'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))))])) else Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [
          DeviceCard(device: _device!, onTap: () => setState(() => _showDetails = !_showDetails), onStatusUpdate: _refreshDevice, onDelete: _deleteDevice),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: (_isTesting || !_deviceOnline) ? null : _startTestNow, icon: _isTesting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.science), label: Text(_isTesting ? 'Testing... ${_testSecondsLeft}s' : 'Test Now'), style: ElevatedButton.styleFrom(backgroundColor: _isTesting ? Colors.orange : const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 3)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestHistoryPage(deviceId: _device!.deviceId))), icon: const Icon(Icons.history), label: const Text('View History'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6), side: const BorderSide(color: Color(0xFF8B5CF6)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), const SizedBox(width: 8), Expanded(child: ElevatedButton.icon(onPressed: () => _downloadPdfReport(context), icon: const Icon(Icons.picture_as_pdf), label: const Text('Download PDF'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))])) ,
          if (_showDetails) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: _buildDeviceDetails()),
        ])),
      ])),
      floatingActionButton: _device == null ? FloatingActionButton.extended(onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddDevicePage(user: widget.user))); if (result == true) await _loadDevice(); }, backgroundColor: const Color(0xFF3B82F6), icon: const Icon(Icons.add), label: const Text('Register Device')) : null,
    );
  }

  Future<void> _downloadPdfReport(BuildContext context) async {
    if (_device == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('devices').doc(_device!.deviceId).collection('test_results').orderBy('timestamp', descending: true) .limit(50).get();
      if (snapshot.docs.isEmpty) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No test results to export'))); return; }
      final readings = snapshot.docs.map((doc) => WaterReading(readingId: doc.id, deviceId: _device!.deviceId, timestamp: (doc.data()['timestamp'] as Timestamp).toDate(), parameters: {'pH': (doc.data()['pH'] as num?)?.toDouble() ?? 0, 'temperature': (doc.data()['temperature'] as num?)?.toDouble() ?? 0, 'tds': (doc.data()['tds'] as num?)?.toDouble() ?? 0}, isSafe: doc.data()['isSafe'] as bool? ?? true, alertsGenerated: false)).toList();
      final file = await ExportService().exportReadingsToPdf(deviceId: _device!.deviceId, deviceName: _device!.deviceName, readings: readings);
      await ExportService().shareFile(file);
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e'))); }
  }

  Widget _buildDeviceDetails() {
    if (_device == null) return const SizedBox.shrink();
    if (_currentReading == null && !_deviceOnline) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Column(children: [Icon(Icons.cloud_off, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Device Offline', style: TextStyle(fontWeight: FontWeight.bold)), Text('No data received recently.', style: TextStyle(color: Colors.grey, fontSize: 12))]));
    if (_currentReading == null) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));

    final reading = _currentReading!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: _buildWaterSafetyStatus(reading)),
      const Divider(height: 32),
      Row(children: [const Icon(Icons.show_chart, color: Color(0xFF3B82F6)), const SizedBox(width: 8), const Text('Live Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), if (_deviceOnline) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade300), borderRadius: BorderRadius.circular(12)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fiber_manual_record, color: Colors.green, size: 8), SizedBox(width: 4), Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))]))]),
      const SizedBox(height: 16),
      GridView.count(crossAxisCount: 2, childAspectRatio: 0.85, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, children: [
        if (reading.containsKey('pH')) _buildReadingCard('pH Level', reading['pH']!.toStringAsFixed(2), '', 'WHO: 6.5-8.5', Colors.blue, Icons.analytics, reading['pH']! >= 6.5 && reading['pH']! <= 8.5),
        if (reading.containsKey('temperature')) _buildReadingCard('Temperature', reading['temperature']!.toStringAsFixed(1), '°C', 'Safe: < 32°C', Colors.red, Icons.thermostat, reading['temperature']! < 32),
        if (reading.containsKey('tds')) _buildReadingCard('TDS', reading['tds']!.toStringAsFixed(0), 'mg/L', 'WHO: < 500', Colors.purple, Icons.water, reading['tds']! < 500),
      ]),
      const Divider(height: 32),
      const Text('Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _buildReadingsGraph(),
    ]);
  }

  Widget _buildReadingCard(String label, String value, String unit, String standard, Color color, IconData icon, bool isSafe) {
    return GestureDetector(
      onTap: () { if (_deviceOnline) Navigator.push(context, MaterialPageRoute(builder: (context) => ParameterDetailPage(parameterName: label, currentValue: double.parse(value), unit: unit, description: 'Details for $label', minSafe: 0, maxSafe: 100, color: color, icon: icon))); },
      child: Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Opacity(opacity: _deviceOnline ? 1.0 : 0.7, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: !_deviceOnline ? Colors.grey : (isSafe ? color : Colors.orange), width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: !_deviceOnline ? Colors.grey : (isSafe ? color : Colors.orange), size: 24), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (!_deviceOnline ? Colors.grey : (isSafe ? color : Colors.orange)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(!_deviceOnline ? 'Offline' : (isSafe ? '✓ Safe' : '⚠ Caution'), style: TextStyle(color: !_deviceOnline ? Colors.grey : (isSafe ? color : Colors.orange), fontSize: 10, fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 12), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 4), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), if (unit.isNotEmpty) Text(' $unit', style: const TextStyle(fontSize: 12, color: Colors.grey))]),
        const SizedBox(height: 8), Text(standard, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      ])))),
    );
  }

  Widget _buildWaterSafetyStatus(Map<String, double> reading) {
    if (!_deviceOnline) return Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)), child: const Column(children: [Icon(Icons.cloud_off, color: Colors.red, size: 48), SizedBox(height: 12), Text('Device Offline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)), SizedBox(height: 8), Text('No recent data received. Displayed values may be stale.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))])));
    final isSafe = (reading['pH'] ?? 7) >= 6.5 && (reading['pH'] ?? 7) <= 8.5 && (reading['temperature'] ?? 20) < 32 && (reading['tds'] ?? 0) < 500;
    final color = isSafe ? Colors.green : Colors.orange;
    return Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)), child: Column(children: [
      Icon(isSafe ? Icons.check_circle : Icons.warning_amber, color: color, size: 48),
      const SizedBox(height: 12), Text(isSafe ? 'SAFE TO DRINK' : 'CAUTION', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 8), Text(isSafe ? 'All parameters are within safe limits.' : 'Some parameters exceed safe ranges.', style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
    ])));
  }

  Widget _buildReadingsGraph() {
    if (_readingHistory.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      _buildSensorGraph('pH Level', _readingHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['pH'] ?? 0)).toList(), Colors.blue, 'Goal: 6.5-8.5', [6.5, 8.5]),
      const SizedBox(height: 16),
      _buildSensorGraph('Temperature (°C)', _readingHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['temperature'] ?? 0)).toList(), Colors.red, 'Goal: < 32', [32]),
      const SizedBox(height: 16),
      _buildSensorGraph('TDS (mg/L)', _readingHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['tds'] ?? 0)).toList(), Colors.purple, 'Goal: < 500', [500]),
    ]);
  }

  Widget _buildSensorGraph(String title, List<FlSpot> spots, Color color, String rangeLabel, List<double> thresholds) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text(rangeLabel, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
      const SizedBox(height: 16),
      SizedBox(height: 150, child: LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), lineBarsData: [
        LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1))),
        for (var t in thresholds) LineChartBarData(spots: List.generate(spots.length, (i) => FlSpot(i.toDouble(), t)), isCurved: false, color: Colors.orange.withValues(alpha: 0.5), barWidth: 1, dashArray: [5, 5], dotData: const FlDotData(show: false)),
      ])))
    ])));
  }

  void _showProfileDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('User Profile'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _profileField('Name', widget.user.fullName), _profileField('Email', widget.user.email), _profileField('Location', widget.user.location),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
  }

  Widget _profileField(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(value)]));
}
