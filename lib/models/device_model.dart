// Device Model and Related Classes

class DeviceLocation {
  final String building;
  final int floor;
  final String room;
  final double? latitude;
  final double? longitude;
  final String description;

  DeviceLocation({
    required this.building,
    required this.floor,
    required this.room,
    this.latitude,
    this.longitude,
    required this.description,
  });

  factory DeviceLocation.fromJson(Map<String, dynamic> json) {
    return DeviceLocation(
      building: json['building'] ?? '',
      floor: json['floor'] ?? 0,
      room: json['room'] ?? '',
      latitude: json['latitude'],
      longitude: json['longitude'],
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'building': building,
      'floor': floor,
      'room': room,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
    };
  }
}

// Device Status Enum
enum DeviceStatus { active, inactive, maintenance, offline }

extension DeviceStatusExtension on DeviceStatus {
  String get displayName {
    switch (this) {
      case DeviceStatus.active:
        return 'Active';
      case DeviceStatus.inactive:
        return 'Inactive';
      case DeviceStatus.maintenance:
        return 'Maintenance';
      case DeviceStatus.offline:
        return 'Offline';
    }
  }

  String get value {
    return toString().split('.').last;
  }
}

// Device Model
class Device {
  final String deviceId;
  final String ownerUid;
  final String deviceName;
  final String deviceType; // e.g., "water_quality_sensor_v1"
  final String serialNumber;
  final DeviceLocation location;
  final DeviceStatus status;
  final String apiKey;
  final DateTime? lastReadingTime;
  final double batteryLevel; // 0-100
  final String firmwareVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  Device({
    required this.deviceId,
    required this.ownerUid,
    required this.deviceName,
    required this.deviceType,
    required this.serialNumber,
    required this.location,
    required this.status,
    required this.apiKey,
    this.lastReadingTime,
    required this.batteryLevel,
    required this.firmwareVersion,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  // Determine color based on status
  String get statusColor {
    switch (status) {
      case DeviceStatus.active:
        return '#10B981'; // Green
      case DeviceStatus.inactive:
        return '#6B7280'; // Gray
      case DeviceStatus.maintenance:
        return '#F59E0B'; // Amber
      case DeviceStatus.offline:
        return '#EF4444'; // Red
    }
  }

  // Get status icon
  String get statusIcon {
    switch (status) {
      case DeviceStatus.active:
        return '✓';
      case DeviceStatus.inactive:
        return '○';
      case DeviceStatus.maintenance:
        return '⚙';
      case DeviceStatus.offline:
        return '✕';
    }
  }

  // Check if device needs attention
  bool get needsAttention =>
      status == DeviceStatus.offline ||
      status == DeviceStatus.maintenance ||
      batteryLevel < 20;

  // Check if device is online
  bool get isOnline => status == DeviceStatus.active;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] ?? '',
      ownerUid: json['owner_uid'] ?? '',
      deviceName: json['device_name'] ?? '',
      deviceType: json['device_type'] ?? '',
      serialNumber: json['serial_number'] ?? '',
      location: DeviceLocation.fromJson(json['location'] ?? {}),
      status: _parseStatus(json['status']),
      apiKey: json['api_key'] ?? '',
      lastReadingTime: json['last_reading_time'] != null
          ? DateTime.parse(json['last_reading_time'])
          : null,
      batteryLevel: (json['battery_level'] ?? 0).toDouble(),
      firmwareVersion: json['firmware_version'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      metadata: json['metadata'] ?? {},
    );
  }

  static DeviceStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return DeviceStatus.active;
      case 'inactive':
        return DeviceStatus.inactive;
      case 'maintenance':
        return DeviceStatus.maintenance;
      case 'offline':
        return DeviceStatus.offline;
      default:
        return DeviceStatus.inactive;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'owner_uid': ownerUid,
      'device_name': deviceName,
      'device_type': deviceType,
      'serial_number': serialNumber,
      'location': location.toJson(),
      'status': status.value,
      'api_key': apiKey,
      'last_reading_time': lastReadingTime?.toIso8601String(),
      'battery_level': batteryLevel,
      'firmware_version': firmwareVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  Device copyWith({
    String? deviceId,
    String? ownerUid,
    String? deviceName,
    String? deviceType,
    String? serialNumber,
    DeviceLocation? location,
    DeviceStatus? status,
    String? apiKey,
    DateTime? lastReadingTime,
    double? batteryLevel,
    String? firmwareVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Device(
      deviceId: deviceId ?? this.deviceId,
      ownerUid: ownerUid ?? this.ownerUid,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      status: status ?? this.status,
      apiKey: apiKey ?? this.apiKey,
      lastReadingTime: lastReadingTime ?? this.lastReadingTime,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

// Device Metadata
class DeviceMetadata {
  final String model;
  final String manufacturer;
  final int maxReadingsPerDay;

  DeviceMetadata({
    required this.model,
    required this.manufacturer,
    required this.maxReadingsPerDay,
  });

  factory DeviceMetadata.fromJson(Map<String, dynamic> json) {
    return DeviceMetadata(
      model: json['model'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      maxReadingsPerDay: json['max_readings_per_day'] ?? 1440,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'manufacturer': manufacturer,
      'max_readings_per_day': maxReadingsPerDay,
    };
  }
}
