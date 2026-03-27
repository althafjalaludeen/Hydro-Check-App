import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class FirebaseService {
  /// Initialize Firebase for the app
  /// Call this in main() before running the app
  static Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        print('✅ Firebase was already initialized');
      }
      print('✅ Firebase initialized successfully');
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        print('✅ Firebase already initialized (caught duplicate error)');
      } else {
        print('❌ Firebase initialization error: $e');
        rethrow;
      }
    }
  }
}
