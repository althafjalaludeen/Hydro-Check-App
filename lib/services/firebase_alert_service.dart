import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/water_quality_alert_service.dart';

class WaterAlert {
  final String alertId;
  final String deviceId;
  final String ownerUid;
  final String mobileNumber;
  final String alertType; // WATER_NOT_SAFE, DEVICE_OFFLINE
  final DateTime timestamp;
  final Map<String, dynamic> unsafeParameters; // Details of unsafe params
  final bool notificationSent;
  final String notificationMethod; // SMS, EMAIL, IN_APP
  final bool acknowledged;
  final DateTime? acknowledgedAt;

  WaterAlert({
    required this.alertId,
    required this.deviceId,
    required this.ownerUid,
    required this.mobileNumber,
    required this.alertType,
    required this.timestamp,
    required this.unsafeParameters,
    required this.notificationSent,
    required this.notificationMethod,
    required this.acknowledged,
    this.acknowledgedAt,
  });

  factory WaterAlert.fromJson(Map<String, dynamic> json) {
    return WaterAlert(
      alertId: json['alertId'] ?? json['alert_id'] ?? '',
      deviceId: json['deviceId'] ?? json['device_id'] ?? '',
      ownerUid: json['ownerUid'] ?? json['owner_uid'] ?? '',
      mobileNumber: json['mobileNumber'] ?? json['mobile_number'] ?? '',
      alertType: json['alertType'] ?? json['alert_type'] ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      unsafeParameters: json['unsafeParameters'] ?? json['unsafe_parameters'] ?? {},
      notificationSent:
          json['notificationSent'] ?? json['notification_sent'] ?? false,
      notificationMethod:
          json['notificationMethod'] ?? json['notification_method'] ?? 'IN_APP',
      acknowledged: json['acknowledged'] ?? false,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'])
          : json['acknowledged_at'] != null
              ? DateTime.parse(json['acknowledged_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alertId': alertId,
      'deviceId': deviceId,
      'ownerUid': ownerUid,
      'mobileNumber': mobileNumber,
      'alertType': alertType,
      'timestamp': timestamp.toIso8601String(),
      'unsafeParameters': unsafeParameters,
      'notificationSent': notificationSent,
      'notificationMethod': notificationMethod,
      'acknowledged': acknowledged,
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    };
  }
}

class FirebaseAlertService {
  static final FirebaseAlertService _instance =
      FirebaseAlertService._internal();

  factory FirebaseAlertService() {
    return _instance;
  }

  FirebaseAlertService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Create a water quality alert when readings are unsafe
  Future<WaterAlert> createWaterQualityAlert({
    required String deviceId,
    required String ownerUid,
    required String mobileNumber,
    required List<WaterQualityAlert> unsafeAlerts,
  }) async {
    try {
      final now = DateTime.now();
      final alertId = 'alert_${now.millisecondsSinceEpoch}';

      // Format unsafe parameters for storage
      final unsafeParams = <String, dynamic>{};
      for (var alert in unsafeAlerts) {
        unsafeParams[alert.parameter] = {
          'currentValue': alert.currentValue,
          'minSafe': alert.minSafe,
          'maxSafe': alert.maxSafe,
          'unit': alert.unit,
          'description': alert.description,
        };
      }

      final waterAlert = WaterAlert(
        alertId: alertId,
        deviceId: deviceId,
        ownerUid: ownerUid,
        mobileNumber: mobileNumber,
        alertType: 'WATER_NOT_SAFE',
        timestamp: now,
        unsafeParameters: unsafeParams,
        notificationSent: false,
        notificationMethod: 'SMS',
        acknowledged: false,
      );

      // Save alert to Firestore
      await _firestore.collection('alerts').doc(alertId).set({
        'alertId': waterAlert.alertId,
        'deviceId': waterAlert.deviceId,
        'ownerUid': waterAlert.ownerUid,
        'mobileNumber': waterAlert.mobileNumber,
        'alertType': waterAlert.alertType,
        'timestamp': waterAlert.timestamp.toIso8601String(),
        'unsafeParameters': waterAlert.unsafeParameters,
        'notificationSent': waterAlert.notificationSent,
        'notificationMethod': waterAlert.notificationMethod,
        'acknowledged': waterAlert.acknowledged,
      });

      print('✅ Water quality alert created: $alertId');
      return waterAlert;
    } catch (e) {
      print('❌ Error creating water quality alert: $e');
      rethrow;
    }
  }



  /// Create device offline alert
  Future<WaterAlert> createDeviceOfflineAlert({
    required String deviceId,
    required String ownerUid,
    required String mobileNumber,
  }) async {
    try {
      final now = DateTime.now();
      final alertId = 'alert_${now.millisecondsSinceEpoch}';

      final offlineAlert = WaterAlert(
        alertId: alertId,
        deviceId: deviceId,
        ownerUid: ownerUid,
        mobileNumber: mobileNumber,
        alertType: 'DEVICE_OFFLINE',
        timestamp: now,
        unsafeParameters: {'reason': 'No reading for more than 1 hour'},
        notificationSent: false,
        notificationMethod: 'SMS',
        acknowledged: false,
      );

      await _firestore.collection('alerts').doc(alertId).set({
        'alertId': offlineAlert.alertId,
        'deviceId': offlineAlert.deviceId,
        'ownerUid': offlineAlert.ownerUid,
        'mobileNumber': offlineAlert.mobileNumber,
        'alertType': offlineAlert.alertType,
        'timestamp': offlineAlert.timestamp.toIso8601String(),
        'unsafeParameters': offlineAlert.unsafeParameters,
        'notificationSent': offlineAlert.notificationSent,
        'notificationMethod': offlineAlert.notificationMethod,
        'acknowledged': offlineAlert.acknowledged,
      });

      print('✅ Device offline alert created: $alertId');
      return offlineAlert;
    } catch (e) {
      print('❌ Error creating device offline alert: $e');
      rethrow;
    }
  }

  /// Get all alerts for a user
  Future<List<WaterAlert>> getUserAlerts({
    required String ownerUid,
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('alerts')
          .where('ownerUid', isEqualTo: ownerUid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => WaterAlert.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching user alerts: $e');
      rethrow;
    }
  }

  /// Get unacknowledged alerts for a user
  Future<List<WaterAlert>> getUnacknowledgedAlerts(String ownerUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('alerts')
          .where('ownerUid', isEqualTo: ownerUid)
          .where('acknowledged', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => WaterAlert.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching unacknowledged alerts: $e');
      rethrow;
    }
  }

  /// Get alerts for specific device
  Future<List<WaterAlert>> getDeviceAlerts({
    required String deviceId,
    int daysBack = 30,
  }) async {
    try {
      final date = DateTime.now().subtract(Duration(days: daysBack));

      final querySnapshot = await _firestore
          .collection('alerts')
          .where('deviceId', isEqualTo: deviceId)
          .where('timestamp', isGreaterThan: date.toIso8601String())
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => WaterAlert.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching device alerts: $e');
      rethrow;
    }
  }

  /// Mark alert as acknowledged
  Future<void> acknowledgeAlert(String alertId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('alerts').doc(alertId).update({
        'acknowledged': true,
        'acknowledgedAt': now.toIso8601String(),
      });

      print('✅ Alert acknowledged: $alertId');
    } catch (e) {
      print('❌ Error acknowledging alert: $e');
      rethrow;
    }
  }

  /// Mark alert as notification sent
  Future<void> markNotificationSent({
    required String alertId,
    required String method,
  }) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'notificationSent': true,
        'notificationMethod': method,
      });

      print('✅ Notification marked as sent: $alertId via $method');
    } catch (e) {
      print('❌ Error marking notification sent: $e');
      rethrow;
    }
  }

  /// Delete old alerts
  Future<void> deleteOldAlerts({
    required int olderThanDays,
  }) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: olderThanDays));

      final querySnapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isLessThan: cutoffDate.toIso8601String())
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Deleted ${querySnapshot.docs.length} old alerts');
    } catch (e) {
      print('❌ Error deleting old alerts: $e');
      rethrow;
    }
  }

  /// Real-time stream of alerts for a user
  Stream<List<WaterAlert>> getUserAlertsStream(String ownerUid) {
    return _firestore
        .collection('alerts')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WaterAlert.fromJson(doc.data()))
          .toList();
    });
  }

  /// Count unacknowledged alerts for a user
  Future<int> countUnacknowledgedAlerts(String ownerUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('alerts')
          .where('ownerUid', isEqualTo: ownerUid)
          .where('acknowledged', isEqualTo: false)
          .count()
          .get();

      return querySnapshot.count ?? 0;
    } catch (e) {
      print('❌ Error counting unacknowledged alerts: $e');
      return 0;
    }
  }
}
