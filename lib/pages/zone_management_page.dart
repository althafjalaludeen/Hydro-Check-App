// Zone Management Page - Admin Only
import 'package:flutter/material.dart';
import '../models/zone_model.dart';
import '../services/zone_service.dart';
import '../services/firebase_device_service.dart';
import '../services/firebase_authentication_service.dart';

class ZoneManagementPage extends StatefulWidget {
  const ZoneManagementPage({super.key});

  @override
  State<ZoneManagementPage> createState() => _ZoneManagementPageState();
}

class _ZoneManagementPageState extends State<ZoneManagementPage> {
  final _zoneService = ZoneService();
  final _deviceService = FirebaseDeviceService();
  final _authService = FirebaseAuthenticationService();

  List<Zone> _zones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    try {
      final zones = await _zoneService.getAllZones();
      setState(() => _zones = zones);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createZone() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Zone Name',
                hintText: 'e.g. North District',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Covers wards 1-5',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create')),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await _zoneService.createZone(
          zoneName: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
        await _loadZones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zone created!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteZone(Zone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone'),
        content: Text('Delete "${zone.zoneName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _zoneService.deleteZone(zone.zoneId);
        await _loadZones();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _manageZoneDevices(Zone zone) async {
    // Get all devices (admin owns them)
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final allDevices = await _deviceService.getUserDevices(currentUser.uid);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final selectedIds = List<String>.from(zone.deviceIds);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Devices in ${zone.zoneName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: allDevices.isEmpty
                  ? const Text('No devices available')
                  : ListView(
                      shrinkWrap: true,
                      children: allDevices.map((device) {
                        final isSelected =
                            selectedIds.contains(device.deviceId);
                        return CheckboxListTile(
                          title: Text(device.deviceName),
                          subtitle: Text(device.deviceId),
                          value: isSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedIds.add(device.deviceId);
                              } else {
                                selectedIds.remove(device.deviceId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  // Update zone device assignments
                  final updated = zone.copyWith(deviceIds: selectedIds);
                  await _zoneService.updateZone(updated);
                  Navigator.pop(context);
                  _loadZones();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _manageZoneStaff(Zone zone) async {
    final subordinates = await _authService.getSubordinates();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final selectedUids = List<String>.from(zone.assignedSubordinates);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Staff in ${zone.zoneName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: subordinates.isEmpty
                  ? const Text('No subordinates available.\nPromote users from Staff Management.')
                  : ListView(
                      shrinkWrap: true,
                      children: subordinates.map((user) {
                        final isSelected = selectedUids.contains(user.uid);
                        return CheckboxListTile(
                          title: Text(user.fullName),
                          subtitle: Text(user.email),
                          value: isSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedUids.add(user.uid);
                              } else {
                                selectedUids.remove(user.uid);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final updated =
                      zone.copyWith(assignedSubordinates: selectedUids);
                  await _zoneService.updateZone(updated);

                  // Update each subordinate's assigned zone
                  for (var uid in selectedUids) {
                    await _zoneService.assignSubordinateToZone(
                        zone.zoneId, uid);
                  }

                  Navigator.pop(context);
                  _loadZones();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Management'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _zones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No zones created yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createZone,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Zone'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadZones,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _zones.length,
                    itemBuilder: (context, index) {
                      final zone = _zones[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      zone.zoneName,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteZone(zone),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                  ),
                                ],
                              ),
                              if (zone.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 32, top: 4),
                                  child: Text(zone.description,
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(width: 32),
                                  Icon(Icons.devices,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${zone.deviceIds.length} devices',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.people,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${zone.assignedSubordinates.length} staff',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(width: 24),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _manageZoneDevices(zone),
                                    icon: const Icon(Icons.devices, size: 16),
                                    label: const Text('Devices'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _manageZoneStaff(zone),
                                    icon: const Icon(Icons.people, size: 16),
                                    label: const Text('Staff'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createZone,
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add),
        label: const Text('New Zone'),
      ),
    );
  }
}
