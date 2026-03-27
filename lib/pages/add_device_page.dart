// Device Registration Page - Add New Devices
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../services/firebase_authentication_service.dart';
import '../services/firebase_device_service.dart'; // Real Service
import '../services/location_service.dart';

class AddDevicePage extends StatefulWidget {
  final User user;
  final User? targetUser; // New optional target user

  const AddDevicePage({
    super.key,
    required this.user,
    this.targetUser,
  });

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = FirebaseAuthenticationService();
  final _deviceService = FirebaseDeviceService(); // Real Service

  List<User> _managedUsers = [];
  User? _selectedUser;

  // Form controllers
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _roomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deviceTypeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.user.isAdmin) {
      _loadManagedUsers();
    }
  }

  Future<void> _loadManagedUsers() async {
    try {
      final users = await _authService.getUsersForAdmin(widget.user.uid);
      if (mounted) {
        setState(() {
          // Add Admin themselves to the list of choices
          _managedUsers = [widget.user, ...users];
          // Pre-select targetUser if provided, otherwise default to Admin
          _selectedUser = widget.targetUser ?? widget.user;
        });
      }
    } catch (e) {
      print('Error loading managed users: $e');
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    _serialNumberController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _roomController.dispose();
    _descriptionController.dispose();
    _deviceTypeController.dispose();
    super.dispose();
  }

  Future<void> _addDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use manual device ID
      final deviceId = _deviceIdController.text.trim();

      // Get GPS location
      final gpsLocation = await LocationService.getCurrentLocationWithTimeout();

      // Create location
      final location = DeviceLocation(
        building: _buildingController.text.trim(),
        floor: int.parse(_floorController.text),
        room: _roomController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: gpsLocation?['latitude'],
        longitude: gpsLocation?['longitude'],
      );

      // Add device
      final targetUserUid = _selectedUser?.uid ?? _user.uid;

      await _deviceService.addDevice(
        ownerUid: targetUserUid,
        deviceName: _deviceNameController.text.trim(),
        serialNumber: _serialNumberController.text.trim(),
        deviceType: _deviceTypeController.text.trim(),
        location: location,
        customDeviceId: deviceId, // Pass the manual ID
        adminUid: widget.user.uid, // Explicitly tag with the logged-in Admin's UID
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Device added successfully${gpsLocation != null ? ' with location' : ' (location unavailable)'}!')),
        );

        // Wait a moment then go back to dashboard
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error adding device: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  get _user => widget.user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Device'),
        centerTitle: true,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter device information and location details',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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

              // Section 1: Device Information
              const Text(
                'Device Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Admin-only User Selection
              if (widget.user.isAdmin) ...[
                const Text(
                  'Assign to User',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<User?>(
                  value: _selectedUser,
                  decoration: InputDecoration(
                    hintText: 'Myself (${widget.user.fullName})',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    DropdownMenuItem<User?>(
                      value: null,
                      child: Text('Myself (${widget.user.fullName})'),
                    ),
                    ..._managedUsers.map((user) {
                      return DropdownMenuItem<User?>(
                        value: user,
                        child: Text('${user.fullName} (${user.role})'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUser = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _deviceIdController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Device ID',
                  hintText: 'e.g., device_001 (Match your ESP32 Code)',
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Device ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _deviceNameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'e.g., Main Tank - Floor 3',
                  prefixIcon: const Icon(Icons.devices),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Device name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _serialNumberController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Serial Number',
                  hintText: 'e.g., SN-2025-001',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Serial number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _deviceTypeController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Device Type',
                  hintText: 'e.g., water_quality_sensor_v1',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Device type is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Section 2: Location
              const Text(
                'Location Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _buildingController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Building Name',
                  hintText: 'e.g., Main Building',
                  prefixIcon: const Icon(Icons.apartment),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Building name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Floor',
                        hintText: '3',
                        prefixIcon: const Icon(Icons.stairs),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Floor is required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _roomController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Room/Area',
                  hintText: 'e.g., Water Tank Room',
                  prefixIcon: const Icon(Icons.room_preferences),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Room/Area is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                enabled: !_isLoading,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Additional notes about the device location',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              // Summary Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Summary',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                        'Device Name',
                        _deviceNameController.text.isEmpty
                            ? '(Not set)'
                            : _deviceNameController.text),
                    _buildSummaryRow(
                        'Serial Number',
                        _serialNumberController.text.isEmpty
                            ? '(Not set)'
                            : _serialNumberController.text),
                    _buildSummaryRow(
                        'Type',
                        _deviceTypeController.text.isEmpty
                            ? '(Not set)'
                            : _deviceTypeController.text),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                        'Location',
                        _buildingController.text.isEmpty
                            ? '(Not set)'
                            : '${_buildingController.text}, Floor ${_floorController.text}'),
                  ],
                ),
              ),
              const SizedBox(height: 80), // Space for bottom bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addDevice,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Device'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
