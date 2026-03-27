import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';

class FirebaseDeviceService {
  static final FirebaseDeviceService _instance =
      FirebaseDeviceService._internal();

  factory FirebaseDeviceService() {
    return _instance;
  }

  FirebaseDeviceService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Get all devices owned by a user
  Future<List<Device>> getUserDevices(String ownerUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('devices')
          .where('owner_uid', isEqualTo: ownerUid)
          .get();

      return querySnapshot.docs
          .map((doc) => Device.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching user devices: $e');
      rethrow;
    }
  }

  /// Get single device by ID
  Future<Device?> getDevice(String deviceId) async {
    try {
      final doc = await _firestore.collection('devices').doc(deviceId).get();

      if (!doc.exists) return null;

      return Device.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching device: $e');
      rethrow;
    }
  }

  /// Add a new device
  Future<Device> addDevice({
    required String ownerUid,
    required String deviceName,
    required String serialNumber,
    required String deviceType,
    required DeviceLocation location,
    String? customDeviceId, // Optional manual ID
    String? adminUid, // Explicit admin UID for aggregation
  }) async {
    try {
      final now = DateTime.now();
      // Use provided ID or generate new on
      final deviceId = customDeviceId != null && customDeviceId.isNotEmpty
          ? customDeviceId
          : 'dev_${now.millisecondsSinceEpoch}';

      final device = Device(
        deviceId: deviceId,
        ownerUid: ownerUid,
        deviceName: deviceName,
        deviceType: deviceType,
        serialNumber: serialNumber,
        location: location,
        status: DeviceStatus.active,
        apiKey: _generateApiKey(),
        lastReadingTime: now,
        firmwareVersion: '1.0.0',
        createdAt: now,
        updatedAt: now,
        metadata: {
          'model': 'WQS-Pro-2000',
          'manufacturer': 'AquaTech',
          'max_readings_per_day': 1440,
        },
      );

      // Fetch target user's adminUid for aggregation
      final userDoc = await _firestore.collection('users').doc(ownerUid).get();
      final derivedAdminUid = adminUid ?? userDoc.data()?['admin_uid'] ?? ownerUid; 

      // Save to Firestore
      await _firestore.collection('devices').doc(deviceId).set({
        'device_id': device.deviceId,
        'owner_uid': device.ownerUid,
        'admin_uid': derivedAdminUid, // Save for system-wide aggregation
        'device_name': device.deviceName,
        'device_type': device.deviceType,
        'serial_number': device.serialNumber,
        'status': device.status.displayName.toLowerCase(),
        'api_key': device.apiKey,
        'last_reading_time': device.lastReadingTime?.toIso8601String(),
        'firmware_version': device.firmwareVersion,
        'created_at': device.createdAt.toIso8601String(),
        'updated_at': device.updatedAt.toIso8601String(),
        'location': {
          'building': location.building,
          'floor': location.floor,
          'room': location.room,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'description': location.description,
        },
        'metadata': device.metadata,
      });

      // Update user's device count
      await _firestore.collection('users').doc(ownerUid).set({
        'device_count': FieldValue.increment(1),
        'updated_at': now.toIso8601String(),
      }, SetOptions(merge: true));

      print('✅ Device added successfully: $deviceId');
      return device;
    } catch (e) {
      print('❌ Error adding device: $e');
      rethrow;
    }
  }

  /// Update device information
  Future<void> updateDevice(Device device) async {
    try {
      await _firestore.collection('devices').doc(device.deviceId).update({
        'device_name': device.deviceName,
        'status': device.status.displayName.toLowerCase(),
        'location': {
          'building': device.location.building,
          'floor': device.location.floor,
          'room': device.location.room,
          'latitude': device.location.latitude,
          'longitude': device.location.longitude,
          'description': device.location.description,
        },
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Device updated successfully');
    } catch (e) {
      print('❌ Error updating device: $e');
      rethrow;
    }
  }

  /// Delete device
  Future<void> deleteDevice(String deviceId, String ownerUid) async {
    try {
      // Delete device document
      await _firestore.collection('devices').doc(deviceId).delete();

      // Delete all readings for this device
      final readings = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .get();

      for (var doc in readings.docs) {
        await doc.reference.delete();
      }

      // Update user's device count
      await _firestore.collection('users').doc(ownerUid).update({
        'device_count': FieldValue.increment(-1),
      });

      print('✅ Device deleted successfully');
    } catch (e) {
      print('❌ Error deleting device: $e');
      rethrow;
    }
  }

  /// Update device status (active, inactive, offline, maintenance)
  Future<void> updateDeviceStatus(
    String deviceId,
    DeviceStatus status,
  ) async {
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'status': status.displayName.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Device status updated to ${status.displayName}');
    } catch (e) {
      print('❌ Error updating device status: $e');
      rethrow;
    }
  }

   // Battery logic removed as per user request


  /// Get all devices for an admin or subordinate's organization
  Future<List<Device>> getDevicesForAdmin(String uid) async {
    try {
      // 1. Get the requesting user's data to check role
      final requesterDoc = await _firestore.collection('users').doc(uid).get();
      if (!requesterDoc.exists) return [];
      
      final data = requesterDoc.data() as Map<String, dynamic>;
      final String role = data['role'] ?? 'user';
      final String? parentAdminUid = data['admin_uid'];

      // 2. Determine target admin UID (either the caller or their parent)
      final String targetAdminUid = (role == 'subordinate' && parentAdminUid != null)
          ? parentAdminUid
          : uid;

      // 3. Get all managed users for this organization
      final usersSnapshot = await _firestore
          .collection('users')
          .where('admin_uid', isEqualTo: targetAdminUid)
          .get();
      
      final managedUids = usersSnapshot.docs.map((doc) => doc.id).toList();
      managedUids.add(targetAdminUid); // Include the admin themselves

      // 4. Query devices. If within whereIn limits (30), use it for perfect legacy coverage.
      // Otherwise, fallback to the scalable admin_uid field.
      QuerySnapshot<Map<String, dynamic>> querySnapshot;
      
      if (managedUids.length <= 30) {
        querySnapshot = await _firestore
            .collection('devices')
            .where('owner_uid', whereIn: managedUids)
            .get();
      } else {
        querySnapshot = await _firestore
            .collection('devices')
            .where(Filter.or(
              Filter('admin_uid', isEqualTo: targetAdminUid),
              Filter('owner_uid', isEqualTo: targetAdminUid),
            ))
            .get();
      }

      return querySnapshot.docs
          .map((doc) => Device.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching admin devices: $e');
      rethrow;
    }
  }

  /// Get statistics for an organization (Admin or Subordinate)
  Future<Map<String, dynamic>> getDeviceStatisticsForAdmin(String uid) async {
    try {
      final devices = await getDevicesForAdmin(uid);
      
      return {
        'total_devices': devices.length,
        'active_devices': devices.where((d) => d.effectiveStatus == DeviceStatus.active).length,
        'offline_devices': devices.where((d) => d.effectiveStatus == DeviceStatus.offline).length,
        'maintenance_devices': devices.where((d) => d.effectiveStatus == DeviceStatus.maintenance).length,
      };
    } catch (e) {
      print('❌ Error getting admin statistics: $e');
      return {
        'total_devices': 0,
        'active_devices': 0,
        'offline_devices': 0,
        'maintenance_devices': 0,
      };
    }
  }

  /// Real-time listener for user's devices
  Stream<List<Device>> getUserDevicesStream(String ownerUid) {
    return _firestore
        .collection('devices')
        .where('owner_uid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Device.fromJson(doc.data())).toList();
    });
  }

  /// Real-time listener for single device
  Stream<Device?> getDeviceStream(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return Device.fromJson(snapshot.data() as Map<String, dynamic>);
    });
  }

  /// Generate unique API key for device
  String _generateApiKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'sk_live_${timestamp}_$random';
  }
}
