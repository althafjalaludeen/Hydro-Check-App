// Export Page - Download data as CSV/PDF
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../services/export_service.dart';
import '../services/firebase_device_service.dart';
import '../services/firebase_water_reading_service.dart';
import '../services/ticket_service.dart';

class ExportPage extends StatefulWidget {
  final User currentUser;
  final bool isEmbedded;

  const ExportPage({
    super.key, 
    required this.currentUser,
    this.isEmbedded = false,
  });

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final _exportService = ExportService();
  final _deviceService = FirebaseDeviceService();
  final _readingService = FirebaseWaterReadingService();
  final _ticketService = TicketService();

  bool _isExporting = false;
  String? _lastExportPath;
  List<Device> _devices = [];
  Set<String> _selectedDeviceIds = {};
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _getExportableDevices();
      setState(() {
        _devices = devices;
        _selectedDeviceIds = devices.map((d) => d.deviceId).toSet();
        _isLoadingDevices = false;
      });
    } catch (e) {
      _showMessage('Error loading devices: $e');
      setState(() => _isLoadingDevices = false);
    }
  }

  Future<List<Device>> _getExportableDevices() async {
    if (widget.currentUser.isAdmin || widget.currentUser.isSubordinate) {
      return await _deviceService.getDevicesForAdmin(widget.currentUser.uid);
    } else {
      return await _deviceService.getUserDevices(widget.currentUser.uid);
    }
  }

  Future<void> _exportReadingsCsv() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Please select at least one device');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final selectedDevices = _devices.where((d) => _selectedDeviceIds.contains(d.deviceId)).toList();
      final Map<Device, List<WaterReading>> consolidatedData = {};

      for (var device in selectedDevices) {
        final readings = await _readingService.getTestResultsHistory(
          deviceId: device.deviceId,
          limit: 100,
        );
        if (readings.isNotEmpty) {
          consolidatedData[device] = readings;
        }
      }

      if (consolidatedData.isEmpty) {
        _showMessage('No readings found for selected devices');
        return;
      }

      final file = await _exportService.exportConsolidatedReadingsToCsv(
        data: consolidatedData,
      );
      _lastExportPath = file.path;
      _showMessage('CSV exported successfully!');
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportReadingsPdf() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Please select at least one device');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final selectedDevices = _devices.where((d) => _selectedDeviceIds.contains(d.deviceId)).toList();
      final Map<Device, List<WaterReading>> consolidatedData = {};

      for (var device in selectedDevices) {
        final readings = await _readingService.getTestResultsHistory(
          deviceId: device.deviceId,
          limit: 100,
        );
        if (readings.isNotEmpty) {
          consolidatedData[device] = readings;
        }
      }

      if (consolidatedData.isEmpty) {
        _showMessage('No readings found for selected devices');
        return;
      }

      final file = await _exportService.exportConsolidatedReadingsToPdf(
        data: consolidatedData,
      );
      _lastExportPath = file.path;
      _showMessage('PDF report generated!');
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportTicketsCsv() async {
    setState(() => _isExporting = true);
    try {
      final tickets = await _ticketService.getAllTickets();
      if (tickets.isEmpty) {
        _showMessage('No tickets found');
        return;
      }
      final file = await _exportService.exportTicketsToCsv(tickets);
      _lastExportPath = file.path;
      await _exportService.shareFile(file);
      _showMessage('Tickets exported successfully!');
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDevicesCsv() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Please select at least one device');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final selectedDevices = _devices.where((d) => _selectedDeviceIds.contains(d.deviceId)).toList();
      final file = await _exportService.exportDeviceListToCsv(selectedDevices);
      _lastExportPath = file.path;
      await _exportService.shareFile(file);
      _showMessage('Device list exported successfully!');
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('Export Data'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: _isExporting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating export...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Data',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                   Text(
                    'Download your data as CSV or PDF files',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoadingDevices)
                    const Center(child: CircularProgressIndicator())
                  else if (_devices.isEmpty)
                    _noDevicesCard()
                  else
                    _buildDeviceSelectionSection(),

                  const SizedBox(height: 24),

                  // Water Readings
                  _exportCard(
                    icon: Icons.water,
                    title: 'Water Readings',
                    description: 'Export water quality data (last 30 days)',
                    color: Colors.blue,
                    actions: [
                      _exportButton('CSV', Icons.table_chart,
                          _exportReadingsCsv),
                      const SizedBox(width: 8),
                      _exportButton(
                          'PDF', Icons.picture_as_pdf, _exportReadingsPdf),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tickets
                  _exportCard(
                    icon: Icons.support_agent,
                    title: 'Tickets / Issues',
                    description: 'Export all ticket reports',
                    color: Colors.orange,
                    actions: [
                      _exportButton(
                          'CSV', Icons.table_chart, _exportTicketsCsv),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Devices
                  _exportCard(
                    icon: Icons.devices,
                    title: 'Device Inventory',
                    description: 'Export device list and status',
                    color: Colors.green,
                    actions: [
                      _exportButton(
                          'CSV', Icons.table_chart, _exportDevicesCsv),
                    ],
                  ),

                  if (_lastExportPath != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last export: $_lastExportPath',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _exportCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required List<Widget> actions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(description,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ),
      ),
    );
  }

  Widget _exportButton(
      String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _selectedDeviceIds.isEmpty ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDeviceSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Devices to Include',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDeviceIds = _devices.map((d) => d.deviceId).toSet();
                    });
                  },
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDeviceIds.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              final isSelected = _selectedDeviceIds.contains(device.deviceId);
              return CheckboxListTile(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedDeviceIds.add(device.deviceId);
                    } else {
                      _selectedDeviceIds.remove(device.deviceId);
                    }
                  });
                },
                title: Text(device.deviceName),
                subtitle: Text(device.deviceId, style: const TextStyle(fontSize: 10)),
                dense: true,
                secondary: Icon(
                  Icons.sensors,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
              );
            },
          ),
        ),
        if (_selectedDeviceIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedDeviceIds.length} device(s) selected',
              style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _noDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          SizedBox(height: 12),
          Text(
            'No managed devices found in your organization.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Please add devices to your organization first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
