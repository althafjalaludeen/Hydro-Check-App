import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/zone_model.dart';

class ZoneService {
  static final ZoneService _instance = ZoneService._internal();

  factory ZoneService() {
    return _instance;
  }

  ZoneService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Create a new zone (admin only)
  Future<Zone> createZone({
    required String zoneName,
    required String description,
  }) async {
    try {
      final now = DateTime.now();
      final zoneId = 'zone_${now.millisecondsSinceEpoch}';

      final zone = Zone(
        zoneId: zoneId,
        zoneName: zoneName,
        description: description,
        createdAt: now,
      );

      await _firestore.collection('zones').doc(zoneId).set(zone.toJson());

      print('✅ Zone created: $zoneId');
      return zone;
    } catch (e) {
      print('❌ Error creating zone: $e');
      rethrow;
    }
  }

  /// Update zone details
  Future<void> updateZone(Zone zone) async {
    try {
      await _firestore
          .collection('zones')
          .doc(zone.zoneId)
          .update(zone.toJson());
      print('✅ Zone updated: ${zone.zoneId}');
    } catch (e) {
      print('❌ Error updating zone: $e');
      rethrow;
    }
  }

  /// Delete zone
  Future<void> deleteZone(String zoneId) async {
    try {
      await _firestore.collection('zones').doc(zoneId).delete();
      print('✅ Zone deleted: $zoneId');
    } catch (e) {
      print('❌ Error deleting zone: $e');
      rethrow;
    }
  }

  /// Get all zones
  Future<List<Zone>> getAllZones() async {
    try {
      final querySnapshot = await _firestore
          .collection('zones')
          .orderBy('zone_name')
          .get();

      return querySnapshot.docs
          .map((doc) => Zone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching zones: $e');
      rethrow;
    }
  }

  /// Get zone by ID
  Future<Zone?> getZone(String zoneId) async {
    try {
      final doc = await _firestore.collection('zones').doc(zoneId).get();
      if (!doc.exists) return null;
      return Zone.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching zone: $e');
      rethrow;
    }
  }

  /// Assign subordinate to a zone
  Future<void> assignSubordinateToZone(
      String zoneId, String subordinateUid) async {
    try {
      await _firestore.collection('zones').doc(zoneId).update({
        'assigned_subordinates': FieldValue.arrayUnion([subordinateUid]),
      });

      // Also update user's assigned zone
      await _firestore.collection('users').doc(subordinateUid).update({
        'assigned_zone': zoneId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Subordinate $subordinateUid assigned to zone $zoneId');
    } catch (e) {
      print('❌ Error assigning subordinate to zone: $e');
      rethrow;
    }
  }

  /// Remove subordinate from zone
  Future<void> removeSubordinateFromZone(
      String zoneId, String subordinateUid) async {
    try {
      await _firestore.collection('zones').doc(zoneId).update({
        'assigned_subordinates': FieldValue.arrayRemove([subordinateUid]),
      });

      await _firestore.collection('users').doc(subordinateUid).update({
        'assigned_zone': null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Subordinate removed from zone $zoneId');
    } catch (e) {
      print('❌ Error removing subordinate from zone: $e');
      rethrow;
    }
  }

  /// Add device to a zone
  Future<void> addDeviceToZone(String zoneId, String deviceId) async {
    try {
      await _firestore.collection('zones').doc(zoneId).update({
        'device_ids': FieldValue.arrayUnion([deviceId]),
      });
      print('✅ Device $deviceId added to zone $zoneId');
    } catch (e) {
      print('❌ Error adding device to zone: $e');
      rethrow;
    }
  }

  /// Remove device from zone
  Future<void> removeDeviceFromZone(String zoneId, String deviceId) async {
    try {
      await _firestore.collection('zones').doc(zoneId).update({
        'device_ids': FieldValue.arrayRemove([deviceId]),
      });
      print('✅ Device $deviceId removed from zone $zoneId');
    } catch (e) {
      print('❌ Error removing device from zone: $e');
      rethrow;
    }
  }

  /// Get zones assigned to a subordinate
  Future<List<Zone>> getZonesForSubordinate(String subordinateUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('zones')
          .where('assigned_subordinates', arrayContains: subordinateUid)
          .get();

      return querySnapshot.docs
          .map((doc) => Zone.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching subordinate zones: $e');
      rethrow;
    }
  }

  /// Real-time stream of all zones
  Stream<List<Zone>> getZoneStream() {
    return _firestore
        .collection('zones')
        .orderBy('zone_name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Zone.fromJson(doc.data()))
          .toList();
    });
  }
}
