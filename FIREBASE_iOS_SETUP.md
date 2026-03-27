# Firebase iOS Setup Guide

## Step 1: Get Your Firebase Configuration File

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `water-quality-monitoring`
3. Click **Project Settings** (gear icon)
4. Under "Your apps" section, find or create an **iOS app**
5. Enter your app's bundle ID:
   ```
   com.example.waterQualityApp
   ```
   (You can find the actual bundle ID in `ios/Runner/Info.plist`)
6. Click **Register app**
7. **Download** the `GoogleService-Info.plist` file

## Step 2: Add GoogleService-Info.plist to Your Project

1. Place the downloaded `GoogleService-Info.plist` file in:
   ```
   ios/Runner/GoogleService-Info.plist
   ```

2. In Xcode:
   - Open `ios/Runner.xcworkspace` (NOT Runner.xcodeproj)
   - Right-click on "Runner" folder
   - Select "Add Files to Runner..."
   - Navigate to and select `GoogleService-Info.plist`
   - Make sure "Copy items if needed" is checked
   - Make sure "Runner" target is selected
   - Click "Add"

3. Your folder structure should look like:
   ```
   ios/
   ├── Runner/
   │   ├── GoogleService-Info.plist    ← Place it here
   │   ├── Info.plist
   │   ├── Runner.xcodeproj
   │   └── ...
   └── Runner.xcworkspace
   ```

## Step 3: Update iOS Info.plist

Open `ios/Runner/Info.plist` and add Firebase permissions:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ... existing content ... -->
    
    <!-- Location permissions for geolocator -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app needs your location to monitor water quality in your area.</string>
    
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>This app needs your location to monitor water quality in your area.</string>
    
    <!-- Notification permissions -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
    
    <!-- Firebase-related settings -->
    <key>FirebaseEnabled</key>
    <true/>
    
    <!-- ... rest of existing content ... -->
</dict>
</plist>
```

## Step 4: Update Podfile

1. Open `ios/Podfile` in a text editor
2. Ensure minimum iOS deployment target is 11.0 or higher:

```ruby
platform :ios, '12.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

## Step 5: Install Dependencies

Run these commands:

```bash
# Remove old iOS build
flutter clean
rm -rf ios/Pods ios/Podfile.lock

# Get Flutter packages
flutter pub get

# Install CocoaPods dependencies
cd ios
pod install --repo-update
cd ..
```

## Step 6: Configure Xcode (if needed)

If you encounter build issues:

1. Open `ios/Runner.xcworkspace` in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select "Runner" in the left panel
3. Select "Runner" under "Targets"
4. Go to **Build Settings** tab
5. Search for "minimum" and set:
   - **iOS Deployment Target**: 12.0 or higher

6. Go to **Build Phases** tab
7. Expand "Link Binary With Libraries"
8. Click "+" and add:
   - CoreLocation.framework (for location)
   - UserNotifications.framework (for notifications)

## Step 7: Get Your Firebase Credentials

1. In Firebase Console, go to **Project Settings**
2. Find the iOS app configuration
3. The `GoogleService-Info.plist` you downloaded contains all credentials
4. Update `lib/services/firebase_options.dart` with iOS values:

```dart
static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_iOS_API_KEY',          // From GoogleService-Info.plist
    appId: 'YOUR_iOS_APP_ID',            // From GoogleService-Info.plist
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT_ID.firebaseio.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.waterQualityApp',  // Your bundle ID
);
```

## Step 8: Test Firebase Setup

Run these commands:

```bash
# Build for iOS simulator
flutter run -d 'iPhone 15'

# OR build for physical device
flutter run -d ios
```

### Check Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com)
2. Go to **Authentication** → **Users**
3. Create a test account via the app
4. User should appear in Firebase Console within 1-2 seconds

### Common Issues

**Issue: "GoogleService-Info.plist not found"**
- Ensure file is in `ios/Runner/`
- Check Xcode file navigator shows the file
- Try removing and re-adding the file

**Issue: "Pod install fails"**
```bash
# Try cleaning and reinstalling
rm -rf ios/Pods ios/Podfile.lock
cd ios
pod deintegrate
pod install --repo-update
cd ..
```

**Issue: "Build error: module not found"**
- Run `flutter pub get` from project root
- Run `pod install --repo-update` from ios/ folder
- Try `flutter clean` and rebuild

**Issue: "Code signing error"**
1. In Xcode, select "Runner" → "Signing & Capabilities"
2. Choose your development team
3. Check "Automatically manage signing"

## Files Modified/Created for iOS

✅ `ios/Runner/GoogleService-Info.plist` - Downloaded from Firebase
✅ `ios/Runner/Info.plist` - Added Firebase and location permissions
✅ `ios/Podfile` - Updated minimum deployment target
✅ `lib/services/firebase_options.dart` - Updated with iOS credentials
✅ `lib/main.dart` - Updated to initialize Firebase
✅ `lib/services/firebase_authentication_service.dart` - Uses Firebase Auth

## Next Steps

1. ⏳ Complete Android setup (see FIREBASE_ANDROID_SETUP.md)
2. ✅ Complete iOS setup (this file)
3. ⏳ Update your authentication pages to use Firebase
4. ⏳ Deploy Cloud Functions for alerts
5. ⏳ Set up Firestore Security Rules

## Testing on Real Device

To test on a real iOS device:

1. Connect iPhone to Mac
2. Run:
   ```bash
   flutter run -d ios
   ```
3. When prompted, allow Firebase notification permissions on the device
4. Test creating an account and logging in
5. Check Firebase Console → Authentication to verify user was created

## Troubleshooting

If you need to debug Firebase initialization:

Add this to your `lib/services/firebase_service.dart`:
```dart
// Enable verbose logging for Firebase
FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
await Firebase.initializeApp(options: options);

// Check connection
print('Firebase connected: ${Firebase.apps.isNotEmpty}');
print('Current user: ${FirebaseAuth.instance.currentUser?.email}');
```
