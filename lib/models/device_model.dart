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
  final String? adminUid; // Added admin_uid field
  final String deviceName;
  final String deviceType; // e.g., "water_quality_sensor_v1"
  final String serialNumber;
  final DeviceLocation location;
  final DeviceStatus status;
  final String apiKey;
  final DateTime? lastReadingTime;
  final String firmwareVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  Device({
    required this.deviceId,
    required this.ownerUid,
    this.adminUid,
    required this.deviceName,
    required this.deviceType,
    required this.serialNumber,
    required this.location,
    required this.status,
    required this.apiKey,
    this.lastReadingTime,
    required this.firmwareVersion,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  // Effective status based on dynamic conditions (Heartbeat)
  DeviceStatus get effectiveStatus {
    // Maintenance and Inactive statuses are manual overrides and should be respected
    if (status == DeviceStatus.maintenance || status == DeviceStatus.inactive) {
      return status;
    }

    // Check heartbeat (10 minute threshold)
    if (lastReadingTime == null) return DeviceStatus.offline;
    final now = DateTime.now();
    if (now.difference(lastReadingTime!).inMinutes < 10) {
      return DeviceStatus.active;
    }
    return DeviceStatus.offline;
  }

  // Determine color based on effective status
  String get statusColor {
    switch (effectiveStatus) {
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
    switch (effectiveStatus) {
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
      effectiveStatus == DeviceStatus.offline ||
      effectiveStatus == DeviceStatus.maintenance;

  // Check if device is online
  bool get isOnline => effectiveStatus == DeviceStatus.active;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      ownerUid: json['owner_uid'] ?? json['ownerUid'] ?? '',
      adminUid: json['admin_uid'] ?? json['adminUid'],
      deviceName: json['device_name'] ?? json['deviceName'] ?? '',
      deviceType: json['device_type'] ?? json['deviceType'] ?? '',
      serialNumber: json['serial_number'] ?? json['serialNumber'] ?? '',
      location: DeviceLocation.fromJson(json['location'] ?? {}),
      status: _parseStatus(json['status']),
      apiKey: json['api_key'] ?? json['apiKey'] ?? '',
      lastReadingTime: json['last_reading_time'] != null
          ? DateTime.parse(json['last_reading_time'])
          : json['lastReadingTime'] != null
              ? DateTime.parse(json['lastReadingTime'])
              : null,
      firmwareVersion: json['firmware_version'] ?? json['firmwareVersion'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt'] ?? DateTime.now().toIso8601String()),
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
      if (adminUid != null) 'admin_uid': adminUid,
      'device_name': deviceName,
      'device_type': deviceType,
      'serial_number': serialNumber,
      'location': location.toJson(),
      'status': status.value,
      'api_key': apiKey,
      'last_reading_time': lastReadingTime?.toIso8601String(),
      'firmware_version': firmwareVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  Device copyWith({
    String? deviceId,
    String? ownerUid,
    String? adminUid,
    String? deviceName,
    String? deviceType,
    String? serialNumber,
    DeviceLocation? location,
    DeviceStatus? status,
    String? apiKey,
    DateTime? lastReadingTime,
    String? firmwareVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Device(
      deviceId: deviceId ?? this.deviceId,
      ownerUid: ownerUid ?? this.ownerUid,
      adminUid: adminUid ?? this.adminUid,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      status: status ?? this.status,
      apiKey: apiKey ?? this.apiKey,
      lastReadingTime: lastReadingTime ?? this.lastReadingTime,
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
