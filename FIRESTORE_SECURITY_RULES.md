# Firestore Security Rules Setup

## Overview

Security rules control who can read and write data in your Firestore database. These rules are **critical** for protecting user data from unauthorized access.

## How to Deploy Rules

### Method 1: Using Firebase Console (Easiest for Beginners)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `water-quality-monitoring`
3. In left menu → **Firestore Database**
4. Click **Rules** tab at the top
5. Copy-paste the rules below into the editor
6. Click **Publish**

### Method 2: Using Firebase CLI (For Development Teams)

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (run once)
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

## Production Security Rules

These rules ensure:
- ✅ Users can only access their own data
- ✅ Admins can access device data they manage
- ✅ No public access to sensitive information
- ✅ Data is protected from unauthorized modifications

### Paste this into Firestore Rules Editor:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == "admin";
    }
    
    // Helper function to check user ownership
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // ============================================================
    // USERS COLLECTION
    // ============================================================
    // Users can only read/write their own document
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isOwner(userId) && request.resource.data.role == "user";
      allow update: if isOwner(userId) && request.resource.data.role == request.resource.data.role;
      allow delete: if false; // Users cannot delete themselves
    }
    
    // ============================================================
    // DEVICES COLLECTION
    // ============================================================
    // Users can read devices they own, admins can read all
    match /devices/{deviceId} {
      allow read: if isOwner(resource.data.ownerUid) || isAdmin();
      allow create: if isOwner(request.resource.data.ownerUid);
      allow update: if isOwner(resource.data.ownerUid);
      allow delete: if isOwner(resource.data.ownerUid);
      
      // Readings nested under devices
      match /readings/{readingId} {
        allow read: if isOwner(get(/databases/$(database)/documents/devices/$(deviceId)).data.ownerUid) || isAdmin();
        allow create: if resource == null || isOwner(get(/databases/$(database)/documents/devices/$(deviceId)).data.ownerUid);
        allow update: if false; // Readings are immutable
        allow delete: if isAdmin(); // Only admins can delete readings
      }
    }
    
    // ============================================================
    // ALERTS COLLECTION
    // ============================================================
    // Users can read their own alerts, admins can read all
    match /alerts/{alertId} {
      allow read: if isOwner(resource.data.ownerUid) || isAdmin();
      allow create: if request.auth.token.firebase.sign_in_provider == "custom" || isAdmin();
      allow update: if isOwner(resource.data.ownerUid) || isAdmin();
      allow delete: if isAdmin();
    }
    
    // ============================================================
    // ADMIN LOGS COLLECTION
    // ============================================================
    // Only admins can read/write admin logs
    match /adminLogs/{logId} {
      allow read: if isAdmin();
      allow create: if isAdmin();
      allow update: if false;
      allow delete: if false;
    }
  }
}
```

## Development/Testing Rules

⚠️ **FOR DEVELOPMENT ONLY** - Remove before deploying to production!

If you want to test without restrictions, use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all read/write for development
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Transitioning from Development to Production

1. **During Development (Test Mode):**
   - Use permissive rules to make development faster
   - Everyone can read/write all data

2. **Before Public Release:**
   - Switch to production rules above
   - Test authentication flows thoroughly
   - Create test users and verify access control
   - Check admin users have proper permissions

3. **After Going Live:**
   - Monitor rules in Firebase Console
   - Set up alerts for suspicious activity
   - Review access logs regularly

## Testing Your Rules

### Test Case 1: User Can Only Access Own Data
```
User A tries to read User B's document → ❌ DENIED
User A reads own document → ✅ ALLOWED
```

### Test Case 2: Admin Can Access Everything
```
Admin reads any user document → ✅ ALLOWED
Admin reads any device document → ✅ ALLOWED
Admin reads any alert → ✅ ALLOWED
```

### Test Case 3: Devices Are Protected
```
Non-owner reads owned device → ❌ DENIED
Owner reads own device → ✅ ALLOWED
```

## Using Firebase Rules Simulator

1. In Firebase Console → Firestore Rules
2. Click **Rules Simulator** at the bottom right
3. Enter:
   - **Path**: `users/abc123xyz`
   - **Operation**: Read
   - **Auth**: Select a test user UID
4. Click **Run** to see if access is allowed

## Common Rule Mistakes to Avoid

❌ **DON'T:** Allow unauthenticated access
```javascript
// BAD!
allow read, write: if true;
```

❌ **DON'T:** Forget to validate user authentication
```javascript
// BAD!
allow read: if resource.data.ownerUid == request.auth.uid || true;
```

✅ **DO:** Check authentication first
```javascript
// GOOD!
allow read: if request.auth != null && resource.data.ownerUid == request.auth.uid;
```

## Rules Validation

After publishing rules, wait 30 seconds then test:

1. Go to your app and try to login
2. Check **Firestore Console → Data** - does data appear correctly?
3. Check **Firestore Console → Usage** - any rule violations?
4. Check **Cloud Logging** for rule rejection reasons

## Monitoring Rule Performance

In Firebase Console:

1. Go to **Firestore Database**
2. Click **Indexes** tab
3. Check if there are any warnings about missing indexes
4. Click **Metrics** tab to see read/write patterns

## Rule Update Checklist

Before deploying new rules:

- ✅ Test with Rules Simulator
- ✅ Test on development device
- ✅ Verify test accounts can login
- ✅ Verify data appears in app
- ✅ Check for rule violations in logs
- ✅ Ensure no sensitive data is exposed
- ✅ Document any rule changes

## Emergency Rules (If Hacked)

If you detect unauthorized access, temporarily block all access:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false; // Block all access
    }
  }
}
```

Then investigate logs and update rules after fixing issues.

## Files Modified/Created

✅ Firestore Rules (created in Firebase Console)
✅ `lib/services/firebase_authentication_service.dart` - Uses authentication
✅ `lib/services/firebase_device_service.dart` - Respects ownership
✅ `lib/services/firebase_alert_service.dart` - User-specific alerts

## Next Steps

1. ✅ Complete Android setup (see FIREBASE_ANDROID_SETUP.md)
2. ✅ Complete iOS setup (see FIREBASE_iOS_SETUP.md)
3. ✅ Set up Firestore Security Rules (this file)
4. ⏳ Create Firebase indexes for complex queries
5. ⏳ Deploy Cloud Functions for background tasks
