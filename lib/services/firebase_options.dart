import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for ${defaultTargetPlatform.name} - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: ' Your API Key Value ',
    appId: ' Your App ID Value ',
    messagingSenderId: ' Your Messaging Sender ID Value ',
    projectId: ' Your Project ID Value ',
    authDomain: ' Your Auth Domain Value ',
    databaseURL: ' Your Database URL Value ',
    storageBucket: ' Your Storage Bucket Value ',
    measurementId: ' Your Measurement ID Value ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: ' Your API Key Value ',
    appId: ' Your App ID Value ',
    messagingSenderId: ' Your Messaging Sender ID Value ',
    projectId: ' Your Project ID Value ',
    databaseURL: ' Your Database URL Value ',
    storageBucket: ' Your Storage Bucket Value ',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: ' Your API Key Value ',
    appId: ' Your App ID Value ',
    messagingSenderId: ' Your Messaging Sender ID Value ',
    projectId: ' Your Project ID Value ',
    databaseURL: ' Your Database URL Value ',
    storageBucket: ' Your Storage Bucket Value ',
    iosBundleId: 'com.example.waterQualityApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: ' Your API Key Value ',
    appId: ' Your App ID Value ',
    messagingSenderId: ' Your Messaging Sender ID Value ',
    projectId: ' Your Project ID Value ',
    databaseURL: ' Your Database URL Value ',
    storageBucket: ' Your Storage Bucket Value ',
    iosBundleId: 'com.example.waterQualityApp',
  );
}
