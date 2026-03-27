// User Model and Authentication Classes

class User {
  final String uid;
  final String email;
  final String fullName;
  final String mobileNumber; // Added mobile number
  final String role; // "user", "admin", or "subordinate"
  final int deviceCount;
  final String location; // Building/Organization name
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> preferences;
  final String? assignedZone; // Zone ID for subordinates
  final String? assignedBy; // Admin UID who assigned this subordinate
  final String? adminUid; // Admin UID who manages this user/subordinate
  final List<String> permissions; // e.g. ['view_devices', 'view_alerts']

  User({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.mobileNumber,
    required this.role,
    required this.deviceCount,
    required this.location,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.preferences = const {},
    this.assignedZone,
    this.assignedBy,
    this.adminUid,
    this.permissions = const [],
  });

  // Determine role based on device count
  static String determineRole(int deviceCount) {
    return deviceCount > 1 ? 'admin' : 'user';
  }

  // Create user from JSON (from backend)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      role: json['role'] ?? 'user',
      deviceCount: json['device_count'] ?? 0,
      location: json['location'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      preferences: json['preferences'] ?? {},
      assignedZone: json['assigned_zone'],
      assignedBy: json['assigned_by'],
      adminUid: json['admin_uid'],
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  // Convert to JSON (for backend)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'role': role,
      'device_count': deviceCount,
      'location': location,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'preferences': preferences,
      'assigned_zone': assignedZone,
      'assigned_by': assignedBy,
      'admin_uid': adminUid,
      'permissions': permissions,
    };
  }

  // Copy with modification
  User copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? mobileNumber,
    String? role,
    int? deviceCount,
    String? location,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
    String? assignedZone,
    String? assignedBy,
    String? adminUid,
    List<String>? permissions,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      deviceCount: deviceCount ?? this.deviceCount,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
      assignedZone: assignedZone ?? this.assignedZone,
      assignedBy: assignedBy ?? this.assignedBy,
      adminUid: adminUid ?? this.adminUid,
      permissions: permissions ?? this.permissions,
    );
  }

  // Check if user is admin
  bool get isAdmin => role == 'admin';

  // Check if user is subordinate
  bool get isSubordinate => role == 'subordinate';

  // Check if user is end user
  bool get isEndUser => role == 'user';

  // Check if user has multiple devices
  bool get hasMultipleDevices => deviceCount > 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

// Authentication Response Model
class AuthResponse {
  final bool success;
  final String message;
  final User? user;
  final String? token;
  final String? error;

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
    this.error,
  });

  factory AuthResponse.success({
    required User user,
    required String token,
    String message = 'Authentication successful',
  }) {
    return AuthResponse(
      success: true,
      message: message,
      user: user,
      token: token,
    );
  }

  factory AuthResponse.error({
    required String error,
    String message = 'Authentication failed',
  }) {
    return AuthResponse(
      success: false,
      message: message,
      error: error,
    );
  }

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      token: json['token'],
      error: json['error'],
    );
  }
}

// Registration Request Model
class RegistrationRequest {
  final String email;
  final String password;
  final String fullName;
  final String mobileNumber;
  final String location;
  final Map<String, dynamic> preferences;
  final String? role;

  RegistrationRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.mobileNumber,
    required this.location,
    this.preferences = const {},
    this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'location': location,
      'preferences': preferences,
      if (role != null) 'role': role,
    };
  }
}

// Login Request Model
class LoginRequest {
  final String email;
  final String password;
  final bool rememberMe;

  LoginRequest({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'remember_me': rememberMe,
    };
  }
}

// User Update Model
class UserUpdate {
  final String? fullName;
  final String? location;
  final Map<String, dynamic>? preferences;

  UserUpdate({
    this.fullName,
    this.location,
    this.preferences,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (fullName != null) json['full_name'] = fullName;
    if (location != null) json['location'] = location;
    if (preferences != null) json['preferences'] = preferences;
    return json;
  }
}
