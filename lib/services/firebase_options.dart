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
    apiKey: 'TODO: Add Web API Key',
    appId: 'TODO: Add Web App ID',
    messagingSenderId: '217576500634',
    projectId: 'hydrocheck-e882a',
    authDomain: 'hydrocheck-e882a.firebaseapp.com',
    databaseURL: 'https://hydrocheck-e882a.firebaseio.com',
    storageBucket: 'hydrocheck-e882a.firebasestorage.app',
    measurementId: 'TODO: Add Web Measurement ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBr6koS5B6IfNvlI5u_SpArr7qfPwVQjMU',
    appId: '1:217576500634:android:0922068e70ec9e58dede23',
    messagingSenderId: '217576500634',
    projectId: 'hydrocheck-e882a',
    databaseURL: 'https://hydrocheck-e882a.firebaseio.com',
    storageBucket: 'hydrocheck-e882a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO: Add iOS API Key',
    appId: 'TODO: Add iOS App ID',
    messagingSenderId: '217576500634',
    projectId: 'hydrocheck-e882a',
    databaseURL: 'https://hydrocheck-e882a.firebaseio.com',
    storageBucket: 'hydrocheck-e882a.firebasestorage.app',
    iosBundleId: 'com.example.waterQualityApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TODO: Add MacOS API Key',
    appId: 'TODO: Add MacOS App ID',
    messagingSenderId: '217576500634',
    projectId: 'hydrocheck-e882a',
    databaseURL: 'https://hydrocheck-e882a.firebaseio.com',
    storageBucket: 'hydrocheck-e882a.firebasestorage.app',
    iosBundleId: 'com.example.waterQualityApp',
  );
}
