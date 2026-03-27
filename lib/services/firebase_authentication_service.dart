import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirebaseAuthenticationService {
  static final FirebaseAuthenticationService _instance =
      FirebaseAuthenticationService._internal();

  factory FirebaseAuthenticationService() {
    return _instance;
  }

  FirebaseAuthenticationService._internal();

  final _auth = fb.FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String? _authToken;

  // Getters
  User? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  fb.User? get firebaseUser => _auth.currentUser;

  /// Register a new user with Firestore
  Future<AuthResponse> register(RegistrationRequest request) async {
    try {
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
          error: 'Invalid mobile number',
          message: 'Please enter a valid mobile number',
        );
      }

      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );

      final uid = userCredential.user!.uid;

      // Check if user was pre-added by admin (invite)
      final existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: request.email)
          .get();

      User newUser;

      if (existingUsers.docs.isNotEmpty) {
        final existingDoc = existingUsers.docs.first;
        final existingData = existingDoc.data();

        newUser = User(
          uid: uid,
          email: request.email,
          fullName: request.fullName,
          mobileNumber: request.mobileNumber,
          role: existingData['role'] ?? 'user',
          deviceCount: 0,
          location: request.location,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          preferences: existingData['preferences'] ?? {},
          assignedZone: existingData['assigned_zone'],
          assignedBy: existingData['assigned_by'],
          adminUid: existingData['admin_uid'],
          permissions: List<String>.from(existingData['permissions'] ?? []),
        );

        // Delete the invite document
        await _firestore.collection('users').doc(existingDoc.id).delete();
      } else {
        // Create new regular user
        newUser = User(
          uid: uid,
          email: request.email,
          fullName: request.fullName,
          mobileNumber: request.mobileNumber,
          role: request.role ??
              'user', // New self-registered users are regular users by default
          deviceCount: 0,
          location: request.location,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          preferences: {
            'theme': 'light',
            'notificationsEnabled': true,
          },
        );
      }

      await _firestore.collection('users').doc(uid).set(newUser.toJson());

      _currentUser = newUser;
      _authToken = await userCredential.user!.getIdToken();

      return AuthResponse.success(
        message: 'Registration successful!',
        user: newUser,
        token: _authToken!,
      );
    } on fb.FirebaseAuthException catch (e) {
      return AuthResponse.error(
        error: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (e) {
      final errorStr = e.toString();
      final code = _extractErrorCode(errorStr);
      return AuthResponse.error(
        error: code ?? 'error',
        message: code != null
            ? _mapAuthError(code)
            : 'Registration failed: $errorStr',
      );
    }
  }

  /// Send forgot password email
  Future<void> forgotPassword(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('Please enter a valid email address');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Login user with email and password
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      if (request.email.isEmpty || request.password.isEmpty) {
        return AuthResponse.error(
          error: 'validation_error',
          message: 'Email and password are required',
        );
      }

      // Authenticate with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );

      final uid = userCredential.user!.uid;

      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return AuthResponse.error(
          error: 'user_not_found',
          message: 'User data not found',
        );
      }

      _currentUser = User.fromJson(userDoc.data() as Map<String, dynamic>);
      _authToken = await userCredential.user!.getIdToken();

      return AuthResponse.success(
        message: 'Login successful!',
        user: _currentUser!,
        token: _authToken!,
      );
    } on fb.FirebaseAuthException catch (e) {
      return AuthResponse.error(
        error: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (e) {
      final errorStr = e.toString();
      final code = _extractErrorCode(errorStr);
      return AuthResponse.error(
        error: code ?? 'error',
        message: code != null ? _mapAuthError(code) : 'Login failed: $errorStr',
      );
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      _authToken = null;
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Logout error: $e');
      rethrow;
    }
  }

  /// Check if user is already logged in on app startup
  Future<void> checkAuthStatus() async {
    try {
      final fbUser = _auth.currentUser;

      if (fbUser != null) {
        final userDoc =
            await _firestore.collection('users').doc(fbUser.uid).get();

        if (userDoc.exists) {
          _currentUser = User.fromJson(userDoc.data() as Map<String, dynamic>);
          _authToken = await fbUser.getIdToken();
          print('✅ User session restored');
        }
      }
    } catch (e) {
      print('❌ Auth status check error: $e');
    }
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile({
    required String fullName,
    required String mobileNumber,
    required String location,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('No user logged in');
      }

      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'full_name': fullName,
        'mobile_number': mobileNumber,
        'location': location,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _currentUser = _currentUser!.copyWith(
        fullName: fullName,
        mobileNumber: mobileNumber,
        location: location,
        updatedAt: DateTime.now(),
      );

      print('✅ User profile updated');
    } catch (e) {
      print('❌ Update profile error: $e');
      rethrow;
    }
  }

  /// Assign a role to a user (admin only)
  Future<void> assignRole({
    required String targetUid,
    required String newRole,
    String? assignedZone,
  }) async {
    if (_currentUser == null) throw Exception('No user logged in');
    if (!isAdmin) throw Exception('Permission denied: admin access required');
    try {
      final updates = <String, dynamic>{
        'role': newRole,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newRole == 'subordinate' && assignedZone != null) {
        updates['assigned_zone'] = assignedZone;
        updates['assigned_by'] = _currentUser?.uid;
        updates['permissions'] = [
          'view_devices',
          'view_alerts',
          'view_tickets'
        ];
      }

      if (newRole == 'user') {
        updates['assigned_zone'] = null;
        updates['assigned_by'] = null;
        updates['permissions'] = [];
      }

      await _firestore.collection('users').doc(targetUid).update(updates);
      print('✅ Role assigned: $targetUid → $newRole');
    } catch (e) {
      print('❌ Error assigning role: $e');
      rethrow;
    }
  }

  /// Get all subordinate users
  Future<List<User>> getSubordinates() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'subordinate')
          .get();

      return querySnapshot.docs
          .map((doc) => User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching subordinates: $e');
      rethrow;
    }
  }

  /// Get all users (admin user management)
  Future<List<User>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching all users: $e');
      rethrow;
    }
  }

  /// Get users managed by current admin or subordinate's parent admin
  Future<List<User>> getUsersForAdmin(String uid) async {
    try {
      // 1. Get the requesting user's data to check role
      final requesterDoc = await _firestore.collection('users').doc(uid).get();
      if (!requesterDoc.exists) return [];

      final requester =
          User.fromJson(requesterDoc.data() as Map<String, dynamic>);

      // 2. Determine target admin UID (either the caller or their parent)
      final String targetAdminUid =
          (requester.role == 'subordinate' && requester.adminUid != null)
              ? requester.adminUid!
              : uid;

      final querySnapshot = await _firestore
          .collection('users')
          .where('admin_uid', isEqualTo: targetAdminUid)
          .get();

      return querySnapshot.docs
          .map((doc) => User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching admin users: $e');
      rethrow;
    }
  }

  /// Add a subordinate (Creates Auth account directly)
  Future<void> addSubordinate({
    required String email,
    required String password,
    required String fullName,
    required String mobileNumber,
    String? assignedZone,
  }) async {
    try {
      if (_currentUser == null) throw Exception('No user logged in');
      if (!isAdmin) throw Exception('Permission denied: admin access required');

      // 1. Create user in Firebase Auth using a secondary app instance
      // This prevents the current Admin from being signed out.
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'TempUserCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      fb.FirebaseAuth tempAuth = fb.FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = userCredential.user!.uid;

      // Cleanup the temporary app
      await tempApp.delete();

      // 2. Create the Firestore user document
      final newUser = User(
        uid: uid,
        email: email.trim(),
        fullName: fullName.trim(),
        mobileNumber: mobileNumber.trim(),
        role: 'subordinate',
        deviceCount: 0,
        location: _currentUser!.location,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        assignedZone: assignedZone,
        assignedBy: _currentUser!.uid,
        adminUid: _currentUser!.uid,
        permissions: ['view_devices', 'view_alerts', 'view_tickets'],
      );

      await _firestore.collection('users').doc(uid).set(newUser.toJson());
      print('✅ Subordinate account created successfully');
    } catch (e) {
      print('❌ Error adding subordinate: $e');
      rethrow;
    }
  }

  /// Add a regular user under this admin (Creates Auth account directly)
  Future<void> addUser({
    required String email,
    required String password,
    required String fullName,
    required String mobileNumber,
  }) async {
    try {
      if (_currentUser == null) throw Exception('No user logged in');
      if (!isAdmin) throw Exception('Permission denied: admin access required');

      // 1. Create user in Firebase Auth using a secondary app instance
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'TempUserCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      fb.FirebaseAuth tempAuth = fb.FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = userCredential.user!.uid;

      // Cleanup the temporary app
      await tempApp.delete();

      // 2. Create the Firestore document
      final newUser = User(
        uid: uid,
        email: email.trim(),
        fullName: fullName.trim(),
        mobileNumber: mobileNumber.trim(),
        role: 'user',
        deviceCount: 0,
        location: _currentUser!.location,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        adminUid: _currentUser!.uid,
      );

      await _firestore.collection('users').doc(uid).set(newUser.toJson());
      print('✅ User account created successfully');
    } catch (e) {
      print('❌ Error adding user: $e');
      rethrow;
    }
  }

  /// Delete a user (Admin only)
  Future<void> deleteUser(String targetUid) async {
    if (_currentUser == null) throw Exception('No user logged in');
    if (!isAdmin) throw Exception('Permission denied: admin access required');
    try {
      await _firestore.collection('users').doc(targetUid).delete();
      print('✅ User deleted: $targetUid');
    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }

  /// Get user by UID
  Future<User?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return User.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching user: $e');
      rethrow;
    }
  }

  /// Maps Firebase Auth error codes to user-friendly messages
  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please wait 15 minutes and try again';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'network-request-failed':
        return 'No internet connection. Please check your network';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      default:
        return 'Something went wrong. Please try again';
    }
  }

  /// Extracts Firebase error code from exception string
  String? _extractErrorCode(String errorString) {
    // Firebase exceptions often contain error codes in brackets or after specific patterns
    final patterns = [
      RegExp(r'\[firebase_auth/([\w-]+)\]'),
      RegExp(r'firebase_auth/([\w-]+)'),
      RegExp(r'"code":"([\w-]+)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(errorString);
      if (match != null) {
        return match.group(1);
      }
    }

    // Check for common error strings
    if (errorString.contains('too-many-requests')) return 'too-many-requests';
    if (errorString.contains('email-already-in-use'))
      return 'email-already-in-use';
    if (errorString.contains('invalid-credential')) return 'invalid-credential';
    if (errorString.contains('network-request-failed'))
      return 'network-request-failed';

    return null;
  }
}
