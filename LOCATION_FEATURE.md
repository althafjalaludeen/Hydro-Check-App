# Location Feature Implementation

## Overview
The Water Quality Monitoring app now supports real-time GPS location capture and display for water quality monitoring devices.

## Features Implemented

### 1. **Automatic GPS Location Capture**
   - When adding a new device, the app automatically requests location permission
   - Captures real-time GPS coordinates (latitude, longitude)
   - Stores coordinates with the device for future reference
   - Gracefully handles cases where location is unavailable

### 2. **Location Display on Dashboards**

#### User Dashboard (Single Device)
- **Location Header Card** displays at the top of the dashboard:
  - Building name, floor, and room
  - GPS coordinates (formatted to 4 decimal places for precision)
  - Icon indicator for visual clarity
  - Wrapped in a semi-transparent container for visibility

#### Admin Device Details Page
- **Location Information Section** shows:
  - Building, floor, room details
  - GPS latitude and longitude (6 decimal places for high precision)
  - All location details visible when viewing individual device monitoring

#### Admin Dashboard (Multi-Device)
- **Device Details Modal** includes:
  - GPS latitude and longitude fields
  - Accessible when viewing device details from the admin dashboard
  - Helps track multiple device locations at once

### 3. **Technical Implementation**

#### New Service: `LocationService` (`lib/services/location_service.dart`)
```dart
class LocationService {
  // Request location permission and get current position
  static Future<Map<String, double>?> getCurrentLocation() async

  // Get location with timeout (10 seconds default)
  static Future<Map<String, double>?> getCurrentLocationWithTimeout() async

  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async

  // Format coordinates for display
  static String formatCoordinates(double latitude, double longitude) -> String
}
```

#### Updated Device Model
- `DeviceLocation` class now includes:
  - `latitude` (optional double)
  - `longitude` (optional double)
  - Backward compatible with existing devices without GPS

#### Updated Pages
1. **lib/pages/add_device_page.dart**
   - Added `location_service.dart` import
   - Modified `_addDevice()` to capture GPS before creating device
   - Shows success message with location status

2. **lib/pages/user_dashboard.dart**
   - Added location card in header showing:
     - Building, floor, room
     - GPS coordinates (4 decimal places)
     - Only displays if GPS data is available

3. **lib/pages/admin_device_details.dart**
   - Added GPS display in location section
     - Latitude with 4 decimal place precision
     - Longitude with 4 decimal place precision

4. **lib/pages/admin_dashboard.dart**
   - Added GPS fields to device details modal
   - Shows latitude and longitude with 6 decimal place precision

### 4. **Dependencies**
- Added `geolocator: ^9.0.2` to pubspec.yaml
  - Handles Android, iOS, and Web location services
  - Automatically manages platform-specific implementations

### 5. **Permissions**

#### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS
- Permissions handled automatically by geolocator package
- Add to Info.plist if needed:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`

### 6. **User Flow**

#### Adding a New Device with Location
1. User navigates to "Add Device"
2. Fills in building, floor, room, and device details
3. Clicks "Add Device" button
4. App requests location permission (if not granted)
5. GPS coordinates are automatically captured with 10-second timeout
6. Device is created with location data
7. User sees success message with location status

#### Viewing Device Location
1. **User Dashboard**: Location with GPS shown in header card
2. **Admin Device Details**: Full location info + GPS coordinates
3. **Admin Dashboard**: GPS details in device info modal

### 7. **Error Handling**
- **Permission Denied**: App prompts user to enable location
- **Location Unavailable**: Device can be added without GPS (location is optional)
- **Timeout**: If GPS takes > 10 seconds, device is added without GPS coordinates
- **Service Disabled**: User can enable location services from settings

### 8. **Testing**
Build Command:
```bash
flutter pub get
flutter build apk
```

Run Command:
```bash
flutter run
```

Test Steps:
1. Register a new user
2. Grant location permission when prompted
3. Add a device - GPS coordinates should be captured
4. View user dashboard - location card should show with GPS
5. View admin details - GPS coordinates should be visible
6. Deny location permission - device can still be added without GPS

### 9. **Future Enhancements**
- Add map view with device pins
- Historical location tracking
- Geofencing alerts
- Distance calculation between devices
- Location-based device grouping
- Export device locations as CSV/KML
- Live location updates with WebSocket

## Summary
✅ GPS location capture implemented
✅ Location storage with devices
✅ Location display on all dashboards
✅ Permission handling
✅ Error handling for missing GPS
✅ Backward compatible with existing devices
