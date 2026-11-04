import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration options for Smart Footwear.
/// Connected to Firebase project: smartfootwear-6d1a6
class SmartFootwearFirebaseConfig {
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'smartfootwear-6d1a6',
  );

  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCV-3xh_NhxhCz6udfz1BKhc2baY0pGq2o',
  );

  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:898116211837:android:4f3872ab3fcc0de4ea4d14',
  );

  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '898116211837',
  );

  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'smartfootwear-6d1a6.firebaseapp.com',
  );

  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'smartfootwear-6d1a6.firebasestorage.app',
  );

  static const String databaseURL = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue:
        'https://smartfootwear-6d1a6-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const String measurementId = 'G-KZ4GYC9GY2';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      projectId.isNotEmpty &&
      projectId != 'smartfootwear-project';

  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      databaseURL: databaseURL,
      measurementId: measurementId,
    );
  }
}
