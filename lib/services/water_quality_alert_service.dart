import 'package:flutter/material.dart';

class WaterQualityAlert {
  final String parameter;
  final double currentValue;
  final double? minSafe;
  final double? maxSafe;
  final String unit;
  final String description;

  WaterQualityAlert({
    required this.parameter,
    required this.currentValue,
    this.minSafe,
    this.maxSafe,
    required this.unit,
    required this.description,
  });

  bool get isUnsafe {
    if (minSafe != null && currentValue < minSafe!) return true;
    if (maxSafe != null && currentValue > maxSafe!) return true;
    return false;
  }

  String get status => isUnsafe ? '⚠️ UNSAFE' : '✓ SAFE';

  String get rangeText {
    if (minSafe != null && maxSafe != null) {
      return '$minSafe-$maxSafe $unit';
    } else if (minSafe != null) {
      return '> $minSafe $unit';
    } else if (maxSafe != null) {
      return '< $maxSafe $unit';
    }
    return 'N/A';
  }
}

class WaterQualityChecker {
  // Check water quality and return list of unsafe parameters
  static List<WaterQualityAlert> checkWaterQuality(
      Map<String, double> readings) {
    final alerts = <WaterQualityAlert>[];

    // pH Check (Safe: 6.5-8.5)
    if (readings.containsKey('pH')) {
      final pH = readings['pH']!;
      alerts.add(
        WaterQualityAlert(
          parameter: 'pH Level',
          currentValue: pH,
          minSafe: 6.5,
          maxSafe: 8.5,
          unit: '',
          description: pH < 6.5
              ? 'Water is too acidic. May cause corrosion of pipes.'
              : pH > 8.5
                  ? 'Water is too alkaline. May cause scaling issues.'
                  : 'pH level is within safe range.',
        ),
      );
    }

    // Turbidity Check (Safe: < 5 NTU)
    if (readings.containsKey('turbidity')) {
      final turbidity = readings['turbidity']!;
      alerts.add(
        WaterQualityAlert(
          parameter: 'Turbidity',
          currentValue: turbidity,
          maxSafe: 5.0,
          unit: 'NTU',
          description: turbidity > 5.0
              ? 'Water is too cloudy. Indicates presence of particles and contaminants.'
              : 'Turbidity is within safe range.',
        ),
      );
    }

    // Temperature Check (Safe: < 25°C)
    if (readings.containsKey('temperature')) {
      final temp = readings['temperature']!;
      alerts.add(
        WaterQualityAlert(
          parameter: 'Temperature',
          currentValue: temp,
          maxSafe: 32.0,
          unit: '°C',
          description: temp > 32.0
              ? 'Water temperature is too high. May promote bacterial growth.'
              : 'Temperature is within safe range.',
        ),
      );
    }

    // Chlorine Check (Safe: 0.2-2.5 mg/L)
    if (readings.containsKey('chlorine')) {
      final chlorine = readings['chlorine']!;
      alerts.add(
        WaterQualityAlert(
          parameter: 'Chlorine',
          currentValue: chlorine,
          minSafe: 0.2,
          maxSafe: 2.5,
          unit: 'mg/L',
          description: chlorine < 0.2
              ? 'Insufficient chlorine for disinfection. Water may be unsafe.'
              : chlorine > 2.5
                  ? 'Chlorine level is too high. May cause health issues.'
                  : 'Chlorine level is within safe range.',
        ),
      );
    }

    // TDS Check (Safe: < 500 mg/L)
    if (readings.containsKey('tds')) {
      final tds = readings['tds']!;
      alerts.add(
        WaterQualityAlert(
          parameter: 'TDS (Total Dissolved Solids)',
          currentValue: tds,
          maxSafe: 500.0,
          unit: 'mg/L',
          description: tds > 500.0
              ? 'TDS is too high. Water may taste bad and contain unwanted minerals.'
              : 'TDS level is within safe range.',
        ),
      );
    }

    // Dissolved Oxygen Check (Safe: > 5 mg/L)
    if (readings.containsKey('dissolvedOxygen')) {
      final do_ = readings['dissolvedOxygen']!;
      alerts.add(
        WaterQualityAlert(
          parameter: 'Dissolved Oxygen',
          currentValue: do_,
          minSafe: 5.0,
          unit: 'mg/L',
          description: do_ < 5.0
              ? 'Dissolved oxygen is too low. Water may not support aquatic life.'
              : 'Dissolved oxygen level is within safe range.',
        ),
      );
    }

    return alerts;
  }

  // Get only unsafe alerts
  static List<WaterQualityAlert> getUnsafeAlerts(Map<String, double> readings) {
    return checkWaterQuality(readings)
        .where((alert) => alert.isUnsafe)
        .toList();
  }

  // Check if water is safe
  static bool isWaterSafe(Map<String, double> readings) {
    return getUnsafeAlerts(readings).isEmpty;
  }

  // Show water quality alert dialog
  static Future<void> showWaterQualityAlert(
    BuildContext context,
    List<WaterQualityAlert> unsafeAlerts,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('⚠️ WATER NOT SAFE TO DRINK'),
            ],
          ),
          titleTextStyle: const TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The following parameters are unsafe:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...unsafeAlerts.map((alert) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert.parameter,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current: ${alert.currentValue.toStringAsFixed(2)} ${alert.unit}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Safe: ${alert.rangeText}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          alert.description,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('OK - I Understand'),
            ),
          ],
        );
      },
    );
  }
}
