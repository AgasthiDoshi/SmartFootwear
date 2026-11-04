import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app.dart';
import 'core/app_controller.dart';
import 'domain/admin_readings_repository.dart';
import 'services/admin_readings_controller.dart';
import 'services/firebase_admin_readings_repository.dart';

import 'core/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseError;
  if (SmartFootwearFirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: SmartFootwearFirebaseConfig.currentPlatform,
      );
    } catch (exception) {
      try {
        // Fallback to default Android google-services.json options if explicit init throws
        await Firebase.initializeApp();
      } catch (inner) {
        firebaseError = 'Firebase initialization notice: $exception';
        debugPrint(firebaseError);
      }
    }

    // Attempt to authenticate anonymously so that "auth != null" database rules succeed:
    if (Firebase.apps.isNotEmpty) {
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
          debugPrint(
            '[SmartFootwear Auth] Anonymous sign-in successful: '
            '${FirebaseAuth.instance.currentUser?.uid}',
          );
        }
      } catch (authError) {
        debugPrint(
          '[SmartFootwear Auth] Note: Anonymous sign-in was not completed ($authError). '
          'If your Realtime Database rules require "auth != null", either enable Anonymous sign-in '
          'in Firebase Console > Authentication > Sign-in method, or set database rules to ".read": true.',
        );
      }
    }
  }

  final AdminReadingsRepository? adminRepository = Firebase.apps.isEmpty
      ? null
      : FirebaseAdminReadingsRepository();
  final controller = AppController(
    adminReadings: AdminReadingsController(
      repository: adminRepository,
      unavailableMessage: firebaseError ??
          'Firebase is not configured. Build with FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID and FIREBASE_PROJECT_ID.',
    ),
  );
  await controller.restore();
  runApp(StrideApp(controller: controller));
}
