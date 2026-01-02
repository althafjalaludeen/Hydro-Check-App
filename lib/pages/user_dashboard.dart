// User Dashboard - Single Device Monitoring
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../services/authentication_service.dart';
import '../services/device_service.dart';
import '../services/water_quality_alert_service.dart';
import '../widgets/device_card_widget.dart';
import 'parameter_detail_page.dart';
import 'reading_history_page.dart';
import 'add_device_page.dart';

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
  late final AuthenticationService _authService;
  late final DeviceService _deviceService;

  Device? _device;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showDetails = false;
  bool _isConnected = false; // Track connection state
  
  // Reading history for graph
  final List<Map<String, double>> _readingHistory = [];
  Map<String, double>? _currentReading;
  Timer? _updateTimer;
  
  // Reading history with timestamps
  final List<Map<String, dynamic>> _readingHistoryWithTime = [];

  @override
  void initState() {
    super.initState();
    _authService = AuthenticationService();
    _deviceService = DeviceService();
    _loadDevice();
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

  void _connectDevice() {
    // Simulate successful connection
    setState(() {
      _isConnected = true;
      _startReadingUpdates(); // Start updates after connection
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device connected successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadDevice() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _deviceService.getUserDevices(widget.user.uid);
      setState(() {
        _device = devices.isNotEmpty ? devices.first : null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load device: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDevice() async {
    if (_device == null) return;

    try {
      await _deviceService.simulateDeviceUpdate(_device!.deviceId, widget.user.uid);
      await _loadDevice();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating device: $e')),
        );
      }
    }
  }

  Future<void> _deleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete ${_device?.deviceName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _device != null) {
      try {
        await _deviceService.removeDevice(_device!.deviceId, widget.user.uid);
        await _authService.updateDeviceCount(0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device deleted successfully')),
          );
          await _loadDevice();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting device: $e')),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Device'),
        centerTitle: true,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevice,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                child: const Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
                onTap: () => _showProfileDialog(),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                onTap: _logout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${widget.user.fullName}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'User • ${widget.user.location}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Location Display
                        if (_device != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_device!.location.building} - Floor ${_device!.location.floor}, ${_device!.location.room}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_device!.location.latitude != null && _device!.location.longitude != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'GPS: ${_device!.location.latitude!.toStringAsFixed(4)}, ${_device!.location.longitude!.toStringAsFixed(4)}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Connection/Setup State
                  if (!_isConnected)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 100,
                            color: Colors.blue.shade300,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Connect Your Device',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'To get started, you need to add and connect a water quality device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Add Device Button
                          if (_device == null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddDevicePage(
                                        user: widget.user,
                                      ),
                                    ),
                                  );
                                  
                                  // Reload device if one was added
                                  if (result == true) {
                                    await _loadDevice();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Device'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          
                          if (_device != null)
                            const SizedBox(height: 0)
                          else
                            const SizedBox(height: 12),
                          
                          // Connect Button
                          if (_device != null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _connectDevice,
                                icon: const Icon(Icons.bluetooth_connected),
                                label: const Text('Connect Device'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Connected Content - Only show if connected
                  if (_isConnected && _device != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          DeviceCard(
                            device: _device!,
                            onTap: () {
                              setState(() => _showDetails = !_showDetails);
                            },
                            onStatusUpdate: _refreshDevice,
                            onDelete: _deleteDevice,
                          ),
                          if (_showDetails)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: _buildDeviceDetails(),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      floatingActionButton: !_isConnected
          ? null
          : (_device == null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device registration coming soon!')),
                    );
                  },
                  backgroundColor: const Color(0xFF3B82F6),
                  icon: const Icon(Icons.add),
                  label: const Text('Register Device'),
                )
              : null),
    );
  }

  Widget _buildDeviceDetails() {
    if (_device == null || _currentReading == null) return const SizedBox.shrink();

    final reading = _currentReading!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safety Status - Featured at Top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildWaterSafetyStatus(reading),
          ),

          const Divider(height: 32),

          // Current Readings Section
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart, color: Color(0xFF3B82F6), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Live Readings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.green, size: 8),
                          SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(
                              fontSize: 11,
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
                
                // Reading Cards Grid
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildReadingCard(
                      'pH Level',
                      (reading['pH'] as double).toStringAsFixed(2),
                      '',
                      'WHO: 6.5-8.5',
                      Colors.blue,
                      Icons.analytics,
                    ),
                    _buildReadingCard(
                      'Turbidity',
                      (reading['turbidity'] as double).toStringAsFixed(2),
                      'NTU',
                      'WHO: < 5',
                      Colors.cyan,
                      Icons.blur_on,
                    ),
                    _buildReadingCard(
                      'Temperature',
                      (reading['temperature'] as double).toStringAsFixed(1),
                      '°C',
                      'WHO: < 25',
                      Colors.red,
                      Icons.thermostat,
                    ),
                    _buildReadingCard(
                      'Chlorine',
                      (reading['chlorine'] as double).toStringAsFixed(2),
                      'mg/L',
                      'WHO: 0.2-2.5',
                      Colors.green,
                      Icons.science,
                    ),
                    _buildReadingCard(
                      'Dissolved Oxygen',
                      (reading['dissolvedOxygen'] as double).toStringAsFixed(2),
                      'mg/L',
                      'WHO: > 5',
                      Colors.teal,
                      Icons.bubble_chart,
                    ),
                    _buildReadingCard(
                      'Total Dissolved Solids',
                      (reading['tds'] as double).toStringAsFixed(0),
                      'mg/L',
                      'WHO: < 500',
                      Colors.purple,
                      Icons.water,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // Safety Analysis Section
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assessment, color: Color(0xFF3B82F6), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Safety Analysis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSafetyIndicator('pH Level', reading['pH'] as double, 6.5, 8.5),
                        _buildSafetyIndicator('Turbidity', reading['turbidity'] as double, 0, 5),
                        _buildSafetyIndicator('Temperature', reading['temperature'] as double, 0, 25),
                        _buildSafetyIndicator('Chlorine', reading['chlorine'] as double, 0.2, 2.5),
                        _buildSafetyIndicator('Dissolved Oxygen', reading['dissolvedOxygen'] as double, 5, 15),
                        _buildSafetyIndicator('TDS', reading['tds'] as double, 0, 500),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // Trends Section
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: Color(0xFF3B82F6), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Readings Trend',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildReadingsGraph(),
              ],
            ),
          ),

          const Divider(height: 32),

          // Device Details Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Device Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Device Info
                        const Text(
                          'Device',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Device ID', _device!.deviceId),
                        _buildDetailRow('Name', _device!.deviceName),
                        _buildDetailRow('Type', _device!.deviceType),
                        _buildDetailRow('Serial', _device!.serialNumber),
                        _buildDetailRow('Firmware', _device!.firmwareVersion),

                        const Divider(height: 24),

                        // Location Info
                        const Text(
                          'Location',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Building', _device!.location.building),
                        _buildDetailRow('Floor', 'Floor ${_device!.location.floor}'),
                        _buildDetailRow('Room', _device!.location.room),
                        _buildDetailRow('Description', _device!.location.description),

                        const Divider(height: 24),

                        // Status Info
                        const Text(
                          'Status',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Last Reading',
                          _device!.lastReadingTime != null
                              ? _formatDateTime(_device!.lastReadingTime!)
                              : 'No readings yet',
                        ),
                        _buildDetailRow('Created', _formatDateTime(_device!.createdAt)),
                        _buildDetailRow('Updated', _formatDateTime(_device!.updatedAt)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // View Reading History Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileField('Name', widget.user.fullName),
            _profileField('Email', widget.user.email),
            _profileField('Role', widget.user.role.toUpperCase()),
            _profileField('Location', widget.user.location),
            _profileField('Devices', '${widget.user.deviceCount}'),
            _profileField(
              'Member Since',
              _formatDate(widget.user.createdAt),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add another device to become an admin',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildReadingCard(
    String label,
    String value,
    String unit,
    String standard,
    Color color,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _showParameterDetail(label, double.parse(value), unit, color, icon),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '✓ Safe',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              standard,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showParameterDetail(String paramName, double value, String unit, Color color, IconData icon) {
    // Get parameter details
    late String description;
    late double minSafe;
    late double maxSafe;

    switch (paramName) {
      case 'pH Level':
        description = 'pH is a measure of acidity or basicity of water. A pH of 7 is neutral, '
            'values below 7 are acidic, and values above 7 are basic (alkaline). '
            'According to WHO standards, drinking water should have a pH between 6.5 and 8.5. '
            'Water outside this range can cause taste issues and may affect water treatment effectiveness.';
        minSafe = 6.5;
        maxSafe = 8.5;
        break;
      case 'Turbidity':
        description = 'Turbidity measures the cloudiness or haziness of water caused by suspended particles. '
            'High turbidity can harbor harmful microorganisms and interfere with water treatment. '
            'WHO recommends turbidity should not exceed 5 NTU (Nephelometric Turbidity Units) for drinking water. '
            'Clear water (low turbidity) is generally safer and more aesthetically pleasing.';
        minSafe = 0;
        maxSafe = 5;
        break;
      case 'Temperature':
        description = 'Water temperature affects chemical reactions and can influence bacterial growth. '
            'Cold water is generally safer as it slows microbial growth. '
            'WHO recommends drinking water temperature should be below 25°C for optimal safety. '
            'High temperatures can promote bacterial proliferation and chemical reactions that affect water quality.';
        minSafe = 0;
        maxSafe = 25;
        break;
      case 'Chlorine':
        description = 'Chlorine is a disinfectant used to kill harmful microorganisms in water. '
            'While beneficial for disinfection, excessive chlorine can affect taste and odor. '
            'WHO recommends free chlorine should be between 0.2-2.5 mg/L for effective disinfection without adverse effects. '
            'Proper chlorination prevents waterborne diseases while maintaining water quality.';
        minSafe = 0.2;
        maxSafe = 2.5;
        break;
      case 'Total Dissolved Solids':
        description = 'TDS represents the total amount of dissolved minerals, salts, and other substances in water. '
            'While some minerals are beneficial, high TDS can affect taste and may indicate contamination. '
            'WHO recommends TDS should not exceed 500 mg/L for drinking water. '
            'Very high TDS levels can make water unpalatable and may pose health risks over long-term consumption.';
        minSafe = 0;
        maxSafe = 500;
        break;
      default:
        description = 'No description available';
        minSafe = 0;
        maxSafe = 100;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParameterDetailPage(
          parameterName: paramName,
          currentValue: value,
          unit: unit,
          description: description,
          minSafe: minSafe,
          maxSafe: maxSafe,
          color: color,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildSafetyIndicator(
    String label,
    double value,
    double minSafe,
    double maxSafe,
  ) {
    final isSafe = value >= minSafe && value <= maxSafe;
    final percentage = isSafe
        ? ((value - minSafe) / (maxSafe - minSafe) * 100).clamp(0, 100)
        : (value > maxSafe ? 150 : -50);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSafe ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSafe ? 'SAFE' : 'CHECK',
                  style: TextStyle(
                    color: isSafe ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isSafe ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Range: $minSafe - $maxSafe | Current: ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _generateDeviceReading() {
    // Generate realistic mock readings with some unsafe readings (30% chance)
    final rng = Random();
    final isUnsafe = rng.nextInt(100) < 30; // 30% chance of unsafe readings
    
    return {
      'pH': isUnsafe && rng.nextInt(5) == 0
          ? (rng.nextBool() ? 5.0 + rng.nextDouble() * 1.5 : 9.0 + rng.nextDouble() * 2.0) // Too acidic or alkaline
          : 6.5 + rng.nextDouble() * 2.0,  // Safe: 6.5 - 8.5
      'turbidity': isUnsafe && rng.nextInt(5) == 1
          ? 5.5 + rng.nextDouble() * 5.0  // Too high: > 5 NTU
          : 1.0 + rng.nextDouble() * 3.0,  // Safe: 1.0 - 4.0
      'temperature': isUnsafe && rng.nextInt(5) == 2
          ? 26.0 + rng.nextDouble() * 8.0  // Too high: > 25°C
          : 20.0 + rng.nextDouble() * 5.0,  // Safe: 20 - 25
      'chlorine': isUnsafe && rng.nextInt(5) == 3
          ? (rng.nextBool() ? 0.0 + rng.nextDouble() * 0.2 : 2.8 + rng.nextDouble() * 2.0) // Too low or too high
          : 0.8 + rng.nextDouble() * 1.5,  // Safe: 0.8 - 2.3
      'tds': isUnsafe && rng.nextInt(5) == 4
          ? 550.0 + rng.nextDouble() * 300.0  // Too high: > 500
          : 250.0 + rng.nextDouble() * 200.0,  // Safe: 250 - 450
      'dissolvedOxygen': isUnsafe && rng.nextInt(5) == 4
          ? 2.0 + rng.nextDouble() * 3.0  // Too low: < 5 mg/L
          : 6.0 + rng.nextDouble() * 4.0,  // Safe: > 5 mg/L
    };
  }

  Widget _buildWaterSafetyStatus(Map<String, double> reading) {
    // Analyze all parameters to determine overall safety
    final pH = reading['pH'] as double;
    final turbidity = reading['turbidity'] as double;
    final temperature = reading['temperature'] as double;
    final chlorine = reading['chlorine'] as double;
    final tds = reading['tds'] as double;

    // Check which parameters are safe
    final pHSafe = pH >= 6.5 && pH <= 8.5;
    final turbiditySafe = turbidity < 5;
    final temperatureSafe = temperature < 25;
    final chlorineSafe = chlorine >= 0.2 && chlorine <= 2.5;
    final tdsSafe = tds < 500;

    final safeCount = [pHSafe, turbiditySafe, temperatureSafe, chlorineSafe, tdsSafe]
        .where((isSafe) => isSafe)
        .length;

    // Determine overall status
    Color statusColor;
    String statusText;
    IconData statusIcon;
    String description;

    if (safeCount == 5) {
      statusColor = Colors.green;
      statusText = 'SAFE TO DRINK';
      statusIcon = Icons.check_circle;
      description = 'All parameters are within WHO standards. Water is safe for consumption.';
    } else if (safeCount >= 3) {
      statusColor = Colors.orange;
      statusText = 'CAUTION';
      statusIcon = Icons.warning_amber;
      description = 'Some parameters are outside safe ranges. Recommend testing before consumption.';
    } else {
      statusColor = Colors.red;
      statusText = 'NOT SAFE';
      statusIcon = Icons.error_outline;
      description = 'Multiple parameters exceed safe limits. Water is not safe for consumption.';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Column(
          children: [
            Icon(statusIcon, color: statusColor, size: 48),
            const SizedBox(height: 12),
            Text(
              'Water Safety Status',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingsGraph() {
    if (_readingHistory.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('Collecting data...'),
          ),
        ),
      );
    }

    // Prepare data for all sensors
    final phSpots = <FlSpot>[];
    final turbiditySpots = <FlSpot>[];
    final tempSpots = <FlSpot>[];
    final chlorineSpots = <FlSpot>[];
    final tdsSpots = <FlSpot>[];
    final doSpots = <FlSpot>[];

    for (int i = 0; i < _readingHistory.length; i++) {
      phSpots.add(FlSpot(i.toDouble(), _readingHistory[i]['pH']!));
      turbiditySpots.add(FlSpot(i.toDouble(), _readingHistory[i]['turbidity']!));
      tempSpots.add(FlSpot(i.toDouble(), _readingHistory[i]['temperature']!));
      chlorineSpots.add(FlSpot(i.toDouble(), _readingHistory[i]['chlorine']!));
      tdsSpots.add(FlSpot(i.toDouble(), _readingHistory[i]['tds']! / 100)); // Scale down for visibility
      doSpots.add(FlSpot(i.toDouble(), _readingHistory[i]['dissolvedOxygen']!));
    }

    return Column(
      children: [
        // pH Graph
        _buildSensorGraph(
          'pH Level',
          phSpots,
          Colors.blue,
          'Safe: 6.5 - 8.5',
          [6.5, 8.5],
        ),
        const SizedBox(height: 20),

        // Turbidity Graph
        _buildSensorGraph(
          'Turbidity (NTU)',
          turbiditySpots,
          Colors.cyan,
          'Safe: < 5 NTU',
          [5],
        ),
        const SizedBox(height: 20),

        // Temperature Graph
        _buildSensorGraph(
          'Temperature (°C)',
          tempSpots,
          Colors.red,
          'Safe: < 25°C',
          [25],
        ),
        const SizedBox(height: 20),

        // Chlorine Graph
        _buildSensorGraph(
          'Chlorine (mg/L)',
          chlorineSpots,
          Colors.green,
            'Safe: 0.2 - 2.5 mg/L',
            [0.2, 2.5],
          ),
          const SizedBox(height: 20),

          // Dissolved Oxygen Graph
          _buildSensorGraph(
            'Dissolved Oxygen (mg/L)',
            doSpots,
            Colors.teal,
            'Safe: > 5 mg/L',
            [5],
          ),
          const SizedBox(height: 20),

          // TDS Graph (scaled by 100 for visibility)
          _buildSensorGraph(
            'TDS (mg/L) / 100',
            tdsSpots,
            Colors.purple,
            'Safe: < 500 mg/L',
            [5], // 500/100 = 5
          ),
        ],
      );
  }

  Widget _buildSensorGraph(
    String title,
    List<FlSpot> spots,
    Color lineColor,
    String safeRangeLabel,
    List<double> safeThresholds,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
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
                    // Actual sensor values
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
                    // Safe threshold lines
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
}
