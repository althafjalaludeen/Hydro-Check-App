import 'package:geolocator/geolocator.dart';

class LocationService {
  // Request location permission and get current position
  static Future<Map<String, double>?> getCurrentLocation() async {
    try {
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null; // Permission denied
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        // Open app settings if permission is permanently denied
        openAppSettings();
        return null;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      // Handle error silently
      return null;
    }
  }

  // Get location with timeout
  static Future<Map<String, double>?> getCurrentLocationWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        openAppSettings();
        return null;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      // Handle error silently
      return null;
    }
  }

  // Open app settings to enable location
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Format coordinates for display
  static String formatCoordinates(double latitude, double longitude) {
    return '$latitude, $longitude';
  }
}
