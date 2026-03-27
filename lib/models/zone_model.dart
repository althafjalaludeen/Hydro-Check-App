// Zone Model for Municipality Zone Management

class Zone {
  final String zoneId;
  final String zoneName;
  final String description;
  final List<String> assignedSubordinates; // UIDs
  final List<String> deviceIds;
  final DateTime createdAt;

  Zone({
    required this.zoneId,
    required this.zoneName,
    required this.description,
    this.assignedSubordinates = const [],
    this.deviceIds = const [],
    required this.createdAt,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      zoneId: json['zone_id'] ?? '',
      zoneName: json['zone_name'] ?? '',
      description: json['description'] ?? '',
      assignedSubordinates:
          List<String>.from(json['assigned_subordinates'] ?? []),
      deviceIds: List<String>.from(json['device_ids'] ?? []),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zone_id': zoneId,
      'zone_name': zoneName,
      'description': description,
      'assigned_subordinates': assignedSubordinates,
      'device_ids': deviceIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Zone copyWith({
    String? zoneId,
    String? zoneName,
    String? description,
    List<String>? assignedSubordinates,
    List<String>? deviceIds,
    DateTime? createdAt,
  }) {
    return Zone(
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      description: description ?? this.description,
      assignedSubordinates:
          assignedSubordinates ?? this.assignedSubordinates,
      deviceIds: deviceIds ?? this.deviceIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
