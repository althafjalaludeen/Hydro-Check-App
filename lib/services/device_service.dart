// Device Service - Manages device data and operations
import 'dart:math';
import '../models/device_model.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();

  factory DeviceService() {
    return _instance;
  }

  DeviceService._internal();

  // Mock device database
  static final Map<String, List<Device>> _userDevices = {
    'user_001': [ // Admin user
      Device(
        deviceId: 'dev_001',
        ownerUid: 'user_001',
        deviceName: 'Main Tank - Floor 3',
        deviceType: 'water_quality_sensor_v1',
        serialNumber: 'SN-2025-001',
        location: DeviceLocation(
          building: 'Main Building',
          floor: 3,
          room: 'Water Tank Room',
          latitude: 40.7128,
          longitude: -74.0060,
          description: 'Primary water tank for building',
        ),
        status: DeviceStatus.active,
        apiKey: 'sk_live_dev001',
        lastReadingTime: DateTime.now(),
        batteryLevel: 95.5,
        firmwareVersion: '1.2.3',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime.now(),
        metadata: {
          'model': 'WQS-Pro-2000',
          'manufacturer': 'AquaTech',
          'max_readings_per_day': 1440,
        },
      ),
      Device(
        deviceId: 'dev_002',
        ownerUid: 'user_001',
        deviceName: 'Backup Tank - Floor 2',
        deviceType: 'water_quality_sensor_v1',
        serialNumber: 'SN-2025-002',
        location: DeviceLocation(
          building: 'Main Building',
          floor: 2,
          room: 'Backup Water Tank',
          latitude: 40.7130,
          longitude: -74.0062,
          description: 'Backup water tank for emergency supply',
        ),
        status: DeviceStatus.active,
        apiKey: 'sk_live_dev002',
        lastReadingTime: DateTime.now().subtract(const Duration(minutes: 5)),
        batteryLevel: 87.2,
        firmwareVersion: '1.2.3',
        createdAt: DateTime(2025, 1, 5),
        updatedAt: DateTime.now(),
        metadata: {
          'model': 'WQS-Pro-2000',
          'manufacturer': 'AquaTech',
          'max_readings_per_day': 1440,
        },
      ),
      Device(
        deviceId: 'dev_003',
        ownerUid: 'user_001',
        deviceName: 'Distribution Line - Floor 1',
        deviceType: 'water_quality_sensor_v2',
        serialNumber: 'SN-2025-003',
        location: DeviceLocation(
          building: 'Main Building',
          floor: 1,
          room: 'Water Distribution Center',
          latitude: 40.7132,
          longitude: -74.0064,
          description: 'Monitors water distribution quality',
        ),
        status: DeviceStatus.offline,
        apiKey: 'sk_live_dev003',
        lastReadingTime: DateTime.now().subtract(const Duration(hours: 2)),
        batteryLevel: 15.0,
        firmwareVersion: '1.3.0',
        createdAt: DateTime(2025, 1, 10),
        updatedAt: DateTime.now(),
        metadata: {
          'model': 'WQS-Basic-1000',
          'manufacturer': 'AquaTech',
          'max_readings_per_day': 1440,
        },
      ),
    ],
    'user_002': [ // Regular user
      Device(
        deviceId: 'dev_004',
        ownerUid: 'user_002',
        deviceName: 'Lab Water System',
        deviceType: 'water_quality_sensor_v1',
        serialNumber: 'SN-2025-004',
        location: DeviceLocation(
          building: 'Research Building',
          floor: 3,
          room: 'Lab Water System',
          latitude: 40.7125,
          longitude: -74.0055,
          description: 'Water quality monitoring for research lab',
        ),
        status: DeviceStatus.active,
        apiKey: 'sk_live_dev004',
        lastReadingTime: DateTime.now(),
        batteryLevel: 92.0,
        firmwareVersion: '1.2.3',
        createdAt: DateTime(2025, 1, 8),
        updatedAt: DateTime.now(),
        metadata: {
          'model': 'WQS-Pro-2000',
          'manufacturer': 'AquaTech',
          'max_readings_per_day': 1440,
        },
      ),
    ],
  };

  // Get all devices for a user
  Future<List<Device>> getUserDevices(String userUid) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _userDevices[userUid] ?? [];
  }

  // Get single device by ID
  Future<Device?> getDeviceById(String deviceId, String userUid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final devices = _userDevices[userUid] ?? [];
    try {
      return devices.firstWhere((d) => d.deviceId == deviceId);
    } catch (e) {
      return null;
    }
  }

  // Add new device
  Future<bool> addDevice(Device device, String userUid) async {
    await Future.delayed(const Duration(seconds: 1));
    if (!_userDevices.containsKey(userUid)) {
      _userDevices[userUid] = [];
    }
    _userDevices[userUid]!.add(device);
    return true;
  }

  // Remove device
  Future<bool> removeDevice(String deviceId, String userUid) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_userDevices.containsKey(userUid)) {
      _userDevices[userUid]!.removeWhere((d) => d.deviceId == deviceId);
      return true;
    }
    return false;
  }

  // Update device
  Future<bool> updateDevice(Device device, String userUid) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_userDevices.containsKey(userUid)) {
      final index = _userDevices[userUid]!.indexWhere((d) => d.deviceId == device.deviceId);
      if (index >= 0) {
        _userDevices[userUid]![index] = device;
        return true;
      }
    }
    return false;
  }

  // Update device status
  Future<bool> updateDeviceStatus(String deviceId, String userUid, DeviceStatus newStatus) async {
    final device = await getDeviceById(deviceId, userUid);
    if (device != null) {
      final updated = device.copyWith(status: newStatus);
      return updateDevice(updated, userUid);
    }
    return false;
  }

  // Update battery level (simulated)
  Future<bool> updateBatteryLevel(String deviceId, String userUid, double newLevel) async {
    final device = await getDeviceById(deviceId, userUid);
    if (device != null) {
      final updated = device.copyWith(batteryLevel: newLevel);
      return updateDevice(updated, userUid);
    }
    return false;
  }

  // Get device count for user
  Future<int> getDeviceCount(String userUid) async {
    final devices = await getUserDevices(userUid);
    return devices.length;
  }

  // Check if all devices are online
  Future<bool> allDevicesOnline(String userUid) async {
    final devices = await getUserDevices(userUid);
    return devices.every((d) => d.isOnline);
  }

  // Get devices needing attention
  Future<List<Device>> getDevicesNeedingAttention(String userUid) async {
    final devices = await getUserDevices(userUid);
    return devices.where((d) => d.needsAttention).toList();
  }

  // Get device statistics
  Future<Map<String, dynamic>> getDeviceStatistics(String userUid) async {
    final devices = await getUserDevices(userUid);
    
    int activeCount = 0;
    int offlineCount = 0;
    int maintenanceCount = 0;
    double totalBattery = 0;
    int lowBatteryCount = 0;

    for (var device in devices) {
      if (device.status == DeviceStatus.active) activeCount++;
      if (device.status == DeviceStatus.offline) offlineCount++;
      if (device.status == DeviceStatus.maintenance) maintenanceCount++;
      totalBattery += device.batteryLevel;
      if (device.batteryLevel < 20) lowBatteryCount++;
    }

    return {
      'total_devices': devices.length,
      'active_devices': activeCount,
      'offline_devices': offlineCount,
      'maintenance_devices': maintenanceCount,
      'average_battery': devices.isEmpty ? 0 : totalBattery / devices.length,
      'low_battery_devices': lowBatteryCount,
      'devices_needing_attention': devices.where((d) => d.needsAttention).length,
    };
  }

  // Simulate real-time update
  Future<void> simulateDeviceUpdate(String deviceId, String userUid) async {
    final device = await getDeviceById(deviceId, userUid);
    if (device != null) {
      // Simulate battery drain
      double newBattery = device.batteryLevel - Random().nextDouble() * 0.5;
      newBattery = newBattery.clamp(0, 100);

      final updated = device.copyWith(
        batteryLevel: newBattery,
        lastReadingTime: DateTime.now(),
      );
      await updateDevice(updated, userUid);
    }
  }

  // Clear all devices (for testing)
  void clearDevices() {
    _userDevices.clear();
  }
}
