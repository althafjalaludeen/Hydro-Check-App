// Authentication Service
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user_model.dart';

class AuthenticationService {
  static final AuthenticationService _instance = AuthenticationService._internal();
  
  factory AuthenticationService() {
    return _instance;
  }

  AuthenticationService._internal();

  // Store current user in memory (in production, use secure storage)
  User? _currentUser;
  String? _authToken;

  // Getters
  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get hasMultipleDevices => _currentUser?.hasMultipleDevices ?? false;

  // Mock database of users (in production, this would be a real backend)
  static final Map<String, Map<String, dynamic>> _userDatabase = {
    'admin@building.com': {
      'uid': 'user_001',
      'email': 'admin@building.com',
      'password_hash': _hashPassword('123'),
      'full_name': 'Admin User',
      'mobile_number': '+1-555-0101',
      'role': 'admin',
      'device_count': 3,
      'location': 'Main Building',
      'is_active': true,
      'created_at': '2025-01-01T10:00:00Z',
      'updated_at': '2025-01-15T14:00:00Z',
      'preferences': {
        'theme': 'light',
        'notifications_enabled': true,
      },
    },
    'user@building.com': {
      'uid': 'user_002',
      'email': 'user@building.com',
      'password_hash': _hashPassword('123'),
      'full_name': 'Regular User',
      'mobile_number': '+1-555-0102',
      'role': 'user',
      'device_count': 1,
      'location': 'Main Building',
      'is_active': true,
      'created_at': '2025-01-05T10:00:00Z',
      'updated_at': '2025-01-15T14:00:00Z',
      'preferences': {
        'theme': 'dark',
        'notifications_enabled': true,
      },
    },
  };

  // Hash password (in production, use bcrypt or similar)
  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // Register new user
  Future<AuthResponse> register(RegistrationRequest request) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Check if user already exists
      if (_userDatabase.containsKey(request.email)) {
        return AuthResponse.error(
          error: 'User already exists',
          message: 'This email is already registered',
        );
      }

      // Validate inputs
      if (request.email.isEmpty || !request.email.contains('@')) {
        return AuthResponse.error(
          error: 'Invalid email',
          message: 'Please enter a valid email address',
        );
      }

      if (request.password.isEmpty || request.password.length < 6) {
        return AuthResponse.error(
          error: 'Invalid password',
          message: 'Password must be at least 6 characters',
        );
      }

      if (request.fullName.isEmpty) {
        return AuthResponse.error(
          error: 'Invalid name',
          message: 'Please enter your full name',
        );
      }

      if (request.mobileNumber.isEmpty) {
        return AuthResponse.error(
          error: 'Invalid phone',
          message: 'Please enter your mobile number',
        );
      }

      // Generate user ID
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      // Create new user (starts with 0 devices, so role is "user")
      _userDatabase[request.email] = {
        'uid': userId,
        'email': request.email,
        'password_hash': _hashPassword(request.password),
        'full_name': request.fullName,
        'mobile_number': request.mobileNumber,
        'role': 'user', // New users start as regular users
        'device_count': 0, // Starts with 0 devices
        'location': request.location,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'preferences': request.preferences,
      };

      // Create user object
      final user = User(
        uid: userId,
        email: request.email,
        fullName: request.fullName,
        mobileNumber: request.mobileNumber,
        role: 'user',
        deviceCount: 0,
        location: request.location,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        preferences: request.preferences,
      );

      // Generate token
      final token = _generateToken(userId);
      _currentUser = user;
      _authToken = token;

      return AuthResponse.success(
        user: user,
        token: token,
        message: 'Registration successful',
      );
    } catch (e) {
      return AuthResponse.error(
        error: e.toString(),
        message: 'Registration failed',
      );
    }
  }

  // Login user
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Find user by email
      if (!_userDatabase.containsKey(request.email)) {
        return AuthResponse.error(
          error: 'User not found',
          message: 'Invalid email or password',
        );
      }

      final userData = _userDatabase[request.email]!;

      // Verify password
      final passwordHash = _hashPassword(request.password);
      if (userData['password_hash'] != passwordHash) {
        return AuthResponse.error(
          error: 'Invalid password',
          message: 'Invalid email or password',
        );
      }

      // Check if account is active
      if (userData['is_active'] != true) {
        return AuthResponse.error(
          error: 'Account inactive',
          message: 'Your account has been deactivated',
        );
      }

      // Create user object
      final user = User(
        uid: userData['uid'],
        email: userData['email'],
        fullName: userData['full_name'],
        mobileNumber: userData['mobile_number'] ?? '',
        role: userData['role'], // Fetch role from database
        deviceCount: userData['device_count'],
        location: userData['location'],
        isActive: userData['is_active'],
        createdAt: DateTime.parse(userData['created_at']),
        updatedAt: DateTime.parse(userData['updated_at']),
        preferences: userData['preferences'] ?? {},
      );

      // Generate token
      final token = _generateToken(userData['uid']);
      _currentUser = user;
      _authToken = token;

      return AuthResponse.success(
        user: user,
        token: token,
        message: 'Login successful',
      );
    } catch (e) {
      return AuthResponse.error(
        error: e.toString(),
        message: 'Login failed',
      );
    }
  }

  // Logout
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authToken = null;
  }

  // Update user profile
  Future<AuthResponse> updateProfile(UserUpdate update) async {
    try {
      if (_currentUser == null) {
        return AuthResponse.error(
          error: 'Not authenticated',
          message: 'User not logged in',
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Update in mock database
      final userData = _userDatabase[_currentUser!.email];
      if (userData != null) {
        if (update.fullName != null) {
          userData['full_name'] = update.fullName;
        }
        if (update.location != null) {
          userData['location'] = update.location;
        }
        if (update.preferences != null) {
          userData['preferences'] = update.preferences;
        }
        userData['updated_at'] = DateTime.now().toIso8601String();
      }

      // Update current user
      _currentUser = _currentUser!.copyWith(
        fullName: update.fullName,
        location: update.location,
        preferences: update.preferences,
        updatedAt: DateTime.now(),
      );

      return AuthResponse.success(
        user: _currentUser!,
        token: _authToken ?? '',
        message: 'Profile updated successfully',
      );
    } catch (e) {
      return AuthResponse.error(
        error: e.toString(),
        message: 'Profile update failed',
      );
    }
  }

  // Update device count and role (called when device is added/removed)
  Future<void> updateDeviceCount(int newDeviceCount) async {
    if (_currentUser == null) return;

    await Future.delayed(const Duration(milliseconds: 300));

    // Update in mock database
    final userData = _userDatabase[_currentUser!.email];
    if (userData != null) {
      userData['device_count'] = newDeviceCount;
      // Auto-determine role based on device count
      userData['role'] = User.determineRole(newDeviceCount);
      userData['updated_at'] = DateTime.now().toIso8601String();
    }

    // Update current user with new role
    final newRole = User.determineRole(newDeviceCount);
    _currentUser = _currentUser!.copyWith(
      deviceCount: newDeviceCount,
      role: newRole,
      updatedAt: DateTime.now(),
    );
  }

  // Verify if user is admin
  bool verifyAdminAccess() {
    return isAdmin && hasMultipleDevices;
  }

  // Generate authentication token
  static String _generateToken(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tokenData = '$userId:$timestamp:${DateTime.now().microsecond}';
    return sha256.convert(utf8.encode(tokenData)).toString();
  }

  // Simulate device added by user (updates device count and role)
  Future<void> addDevice() async {
    if (_currentUser == null) return;
    await updateDeviceCount(_currentUser!.deviceCount + 1);
  }

  // Simulate device removed by user (updates device count and role)
  Future<void> removeDevice() async {
    if (_currentUser == null) return;
    if (_currentUser!.deviceCount > 0) {
      await updateDeviceCount(_currentUser!.deviceCount - 1);
    }
  }

  // Get role description
  String getRoleDescription() {
    if (_currentUser == null) return 'Not authenticated';
    
    if (_currentUser!.isAdmin) {
      return 'Administrator (${_currentUser!.deviceCount} devices)';
    } else {
      return 'User (${_currentUser!.deviceCount} device)';
    }
  }

  // Clear all data (for testing)
  void clearSession() {
    _currentUser = null;
    _authToken = null;
  }
}
