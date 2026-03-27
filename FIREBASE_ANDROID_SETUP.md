# Firebase Android Setup Guide

## Step 1: Get Your Firebase Configuration File

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `water-quality-monitoring`
3. Click **Project Settings** (gear icon)
4. Under "Your apps" section, find or create an **Android app**
5. Enter your app's package name:
   ```
   com.example.water_quality_app
   ```
   (Or check your AndroidManifest.xml for the actual package name)
6. Click **Register app**
7. **Download** the `google-services.json` file

## Step 2: Add google-services.json to Your Project

1. Place the downloaded `google-services.json` file in:
   ```
   android/app/google-services.json
   ```

2. Your folder structure should look like:
   ```
   android/
   ├── app/
   │   ├── google-services.json       ← Place it here
   │   ├── src/
   │   └── build.gradle.kts
   ├── build.gradle.kts
   └── settings.gradle.kts
   ```

## Step 3: Update build.gradle Files

### Update `android/build.gradle.kts`
Add Google Services plugin classpath:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")  // Add this line
    }
}

plugins {
    id("com.android.application") version "8.1.0" apply false
    id("com.android.library") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
}
```

### Update `android/app/build.gradle.kts`
Add Google Services plugin and Firebase dependencies:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")  // Add this line
    id("kotlin-android")
}

android {
    namespace = "com.example.water_quality_app"  // Match your package name
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.water_quality_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Firebase dependencies (auto-added by google-services.json)
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    
    // Other dependencies
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
}
```

## Step 4: Update AndroidManifest.xml Permissions

Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.water_quality_app">

    <!-- Internet permission for Firebase -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- Location permissions (for geolocator package) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application
        android:label="Water Quality Monitor"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Firebase Cloud Messaging Service -->
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

## Step 5: Update gradle.properties

Make sure `android/gradle.properties` has:

```properties
org.gradle.jvmargs=-Xmx4096m
android.useAndroidX=true
android.enableJetifier=true

# Kotlin
kotlin.code.style=official
```

## Step 6: Get Your Firebase Credentials

1. In Firebase Console, go to **Project Settings**
2. Find the Android app configuration
3. Copy these values to update `lib/services/firebase_options.dart`:

```dart
static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',        // From firebase config
    appId: 'YOUR_ANDROID_APP_ID',          // From firebase config
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',  // From firebase config
    projectId: 'YOUR_PROJECT_ID',          // From firebase config
    databaseURL: 'https://YOUR_PROJECT_ID.firebaseio.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
);
```

## Step 7: Test Firebase Setup

Run these commands to verify setup:

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on Android device/emulator
flutter run
```

### Check Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com)
2. Go to **Authentication** → **Users**
3. Create a test account via the app
4. User should appear in Firebase Console within 1-2 seconds

### Common Issues

**Issue: "google-services.json not found"**
- Ensure `android/app/google-services.json` exists
- Run `flutter pub get` again

**Issue: "API key not found"**
- Check `firebase_options.dart` has correct values
- Double-check values match Firebase Console exactly

**Issue: "Failed to initialize Firebase"**
- Make sure internet permission is in AndroidManifest.xml
- Check device has internet connection
- Try `flutter clean` and rebuild

## Files Modified/Created for Android

✅ `android/app/google-services.json` - Downloaded from Firebase
✅ `android/app/build.gradle.kts` - Updated with Firebase dependencies
✅ `android/build.gradle.kts` - Updated with Google Services plugin
✅ `android/app/src/main/AndroidManifest.xml` - Added permissions
✅ `lib/services/firebase_options.dart` - Updated with credentials
✅ `lib/main.dart` - Updated to initialize Firebase
✅ `lib/services/firebase_authentication_service.dart` - Uses Firebase Auth

## Next Steps

1. ✅ Complete Android setup (this file)
2. ⏳ Complete iOS setup (see FIREBASE_iOS_SETUP.md)
3. ⏳ Update your authentication pages to use Firebase
4. ⏳ Deploy Cloud Functions for alerts
5. ⏳ Set up Firestore Security Rules
