import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/water_quality_alert_service.dart';

class WaterReading {
  final String readingId;
  final String deviceId;
  final DateTime timestamp;
  final Map<String, double> parameters; // pH, turbidity, temperature, etc.
  final bool isSafe;
  final bool alertsGenerated;

  WaterReading({
    required this.readingId,
    required this.deviceId,
    required this.timestamp,
    required this.parameters,
    required this.isSafe,
    required this.alertsGenerated,
  });

  factory WaterReading.fromJson(Map<String, dynamic> json) {
    return WaterReading(
      readingId: json['readingId'] ?? json['reading_id'] ?? '',
      deviceId: json['deviceId'] ?? json['device_id'] ?? '',
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.parse(
              json['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
      parameters: Map<String, double>.from(
        (json['parameters'] as Map?)?.map(
              (key, value) =>
                  MapEntry(key as String, (value as num).toDouble()),
            ) ??
            {},
      ),
      isSafe: json['isSafe'] ?? json['is_safe'] ?? true,
      alertsGenerated:
          json['alertsGenerated'] ?? json['alerts_generated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'readingId': readingId,
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'parameters': parameters,
      'isSafe': isSafe,
      'alertsGenerated': alertsGenerated,
    };
  }
}

class FirebaseWaterReadingService {
  static final FirebaseWaterReadingService _instance =
      FirebaseWaterReadingService._internal();

  factory FirebaseWaterReadingService() {
    return _instance;
  }

  FirebaseWaterReadingService._internal();

  final _firestore = FirebaseFirestore.instance;

  /// Save a new water quality reading
  /// Also checks if water is safe and generates alerts if needed
  Future<WaterReading> saveReading({
    required String deviceId,
    required Map<String, double> parameters,
  }) async {
    try {
      final now = DateTime.now();
      final readingId =
          'read_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}';

      // Check if water is safe
      final isSafe = WaterQualityChecker.isWaterSafe(parameters);

      final reading = WaterReading(
        readingId: readingId,
        deviceId: deviceId,
        timestamp: now,
        parameters: parameters,
        isSafe: isSafe,
        alertsGenerated: false,
      );

      // Save to Firestore
      await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .doc(readingId)
          .set({
        'readingId': reading.readingId,
        'deviceId': reading.deviceId,
        'timestamp': reading.timestamp.toIso8601String(),
        'parameters': reading.parameters,
        'isSafe': reading.isSafe,
        'alertsGenerated': reading.alertsGenerated,
      });

      // Update device's last reading time
      await _firestore.collection('devices').doc(deviceId).update({
        'lastReadingTime': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      print('✅ Water reading saved: $readingId');
      return reading;
    } catch (e) {
      print('❌ Error saving water reading: $e');
      rethrow;
    }
  }

  /// Get readings for a device (optional: limit to last N days)
  Future<List<WaterReading>> getReadingHistory({
    required String deviceId,
    int daysBack = 30,
  }) async {
    try {
      final date = DateTime.now().subtract(Duration(days: daysBack));

      final querySnapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .where('timestamp', isGreaterThan: date.toIso8601String())
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => WaterReading.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching reading history: $e');
      rethrow;
    }
  }

  /// Get test results for a device (from the 'test_results' collection)
  Future<List<WaterReading>> getTestResultsHistory({
    required String deviceId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return WaterReading(
          readingId: doc.id,
          deviceId: deviceId,
          timestamp: data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
          parameters: {
            'pH': (data['pH'] as num?)?.toDouble() ?? 0,
            'temperature': (data['temperature'] as num?)?.toDouble() ?? 0,
            'tds': (data['tds'] as num?)?.toDouble() ?? 0,
            'turbidity': (data['turbidity'] as num?)?.toDouble() ?? 0,
            'chlorine': (data['chlorine'] as num?)?.toDouble() ?? 0,
          },
          isSafe: data['isSafe'] as bool? ?? true,
          alertsGenerated: false,
        );
      }).toList();
    } catch (e) {
      print('❌ Error fetching test results: $e');
      rethrow;
    }
  }

  /// Get latest reading for a device
  Future<WaterReading?> getLatestReading(String deviceId) async {
    try {
      final querySnapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return WaterReading.fromJson(querySnapshot.docs.first.data());
    } catch (e) {
      print('❌ Error fetching latest reading: $e');
      rethrow;
    }
  }

  /// Get all unsafe readings for a device
  Future<List<WaterReading>> getUnsafeReadings(String deviceId) async {
    try {
      final querySnapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .where('isSafe', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => WaterReading.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching unsafe readings: $e');
      rethrow;
    }
  }

  /// Get readings within a date range
  Future<List<WaterReading>> getReadingsByDateRange({
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .where('timestamp',
              isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('timestamp', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => WaterReading.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching readings by date range: $e');
      rethrow;
    }
  }

  /// Get average parameters for a device over period
  Future<Map<String, double>> getAverageParameters({
    required String deviceId,
    int daysBack = 7,
  }) async {
    try {
      final readings = await getReadingHistory(
        deviceId: deviceId,
        daysBack: daysBack,
      );

      if (readings.isEmpty) {
        return {};
      }

      final averages = <String, double>{};

      // Get all parameter names
      final allParameters = <String>{};
      for (var reading in readings) {
        allParameters.addAll(reading.parameters.keys);
      }

      // Calculate average for each parameter
      for (var param in allParameters) {
        double sum = 0;
        int count = 0;

        for (var reading in readings) {
          if (reading.parameters.containsKey(param)) {
            sum += reading.parameters[param]!;
            count++;
          }
        }

        if (count > 0) {
          averages[param] = sum / count;
        }
      }

      return averages;
    } catch (e) {
      print('❌ Error calculating average parameters: $e');
      rethrow;
    }
  }

  /// Real-time stream of readings for a device
  Stream<List<WaterReading>> getReadingStream(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WaterReading.fromJson(doc.data()))
          .toList();
    });
  }

  /// Delete old readings (for maintenance/cleanup)
  Future<void> deleteOldReadings({
    required String deviceId,
    required int olderThanDays,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));

      final querySnapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('readings')
          .where('timestamp', isLessThan: cutoffDate.toIso8601String())
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Deleted ${querySnapshot.docs.length} old readings');
    } catch (e) {
      print('❌ Error deleting old readings: $e');
      rethrow;
    }
  }
}
