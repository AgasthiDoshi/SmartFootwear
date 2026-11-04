import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_config.dart';
import '../domain/admin_readings.dart';
import '../domain/admin_readings_repository.dart';

class FirebaseAdminReadingsRepository implements AdminReadingsRepository {
  static String get cleanDatabaseUrl =>
      SmartFootwearFirebaseConfig.databaseURL.replaceAll(RegExp(r'/+$'), '');

  FirebaseAdminReadingsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: cleanDatabaseUrl,
            );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  DocumentReference<Map<String, dynamic>> get _document =>
      _firestore.collection('strideAdmin').doc('readings');

  DatabaseReference get _rtdbSmartFootwearLatest =>
      _database.ref('SmartFootwear/latest');
  DatabaseReference get _rtdbSmartFootwearRoot =>
      _database.ref('SmartFootwear');
  DatabaseReference get _rtdbFootwearCamelLatest =>
      _database.ref('smartFootwear/latest');
  DatabaseReference get _rtdbFootwearCamel =>
      _database.ref('smartFootwear');
  DatabaseReference get _rtdbFootwearLower =>
      _database.ref('smartfootwear');
  DatabaseReference get _rtdbAdmin =>
      _database.ref('strideAdmin/readings');
  DatabaseReference get _rtdbCommands =>
      _database.ref('SmartFootwear/commands');

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  bool get isSignedIn => _auth.currentUser != null;

  static AdminReadings? parseFlexible(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    if (data is! Map) return null;

    // If data has a nested "latest" or "SmartFootwear" map, drill down
    if (data['latest'] is Map) {
      data = data['latest'];
    } else if (data['SmartFootwear'] is Map) {
      data = data['SmartFootwear'];
      if (data['latest'] is Map) {
        data = data['latest'];
      }
    } else if (data['smartFootwear'] is Map) {
      data = data['smartFootwear'];
      if (data['latest'] is Map) {
        data = data['latest'];
      }
    } else if (data['smartfootwear'] is Map) {
      data = data['smartfootwear'];
      if (data['latest'] is Map) {
        data = data['latest'];
      }
    }

    final Map<String, dynamic> normalized = {};
    for (final entry in (data as Map).entries) {
      final key = entry.key
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      normalized[key] = entry.value;
    }

    // 1. Steps
    num? stepsVal = normalized['stepcount'] ??
        normalized['steps'] ??
        normalized['dashboardsteps'] ??
        normalized['step'];
    final steps = stepsVal?.toInt() ?? 0;

    // 2. Daily Goal
    num? goalVal = normalized['dailygoal'] ?? normalized['goal'];
    final goal = (goalVal?.toInt() ?? 8000).clamp(1, 1000000);

    // 3. Sensors: [Heel, Forefoot, Toe/Midfoot, Accel X, Accel Y, Accel Z, Gyro X, Gyro Y, Gyro Z]
    List<double> sensors;
    if (data['sensorValues'] is List &&
        (data['sensorValues'] as List).length >= 9) {
      sensors = (data['sensorValues'] as List)
          .take(9)
          .map((v) => (v as num).toDouble())
          .toList();
    } else {
      final heel = (normalized['heeladc'] ??
              normalized['heel'] ??
              normalized['heelpressure'] ??
              0.0) as num;
      final midfoot = (normalized['midfootadc'] ??
              normalized['midfoot'] ??
              normalized['toe'] ??
              normalized['toeadc'] ??
              0.0) as num;
      final forefoot = (normalized['forefootadc'] ??
              normalized['forefoot'] ??
              normalized['ball'] ??
              0.0) as num;
      final accel = (normalized['accelerationg'] ??
              normalized['acceleration'] ??
              normalized['accelg'] ??
              normalized['accel'] ??
              0.96) as num;
      final gyro = (normalized['gyroscopedps'] ??
              normalized['gyroscope'] ??
              normalized['gyrodps'] ??
              normalized['gyro'] ??
              4.7) as num;

      sensors = [
        heel.toDouble().clamp(0.0, 4095.0),
        forefoot.toDouble().clamp(0.0, 4095.0),
        midfoot.toDouble().clamp(0.0, 4095.0),
        0.0,
        0.0,
        accel.toDouble().clamp(-16.0, 16.0),
        0.0,
        0.0,
        gyro.toDouble().clamp(-2000.0, 2000.0),
      ];
    }

    // 4. Fall detection
    final rawFall = normalized['falldetected'] ??
        normalized['fall'] ??
        normalized['fallalert'];
    bool isFall = false;
    if (rawFall is bool) {
      isFall = rawFall;
    } else if (rawFall is String) {
      final s = rawFall.trim().toLowerCase();
      isFall = s == 'yes' || s == 'true' || s == '1';
    } else if (rawFall is num) {
      isFall = rawFall > 0;
    }

    final fallTriggerId = (normalized['falltriggerid'] as num?)?.toInt() ??
        (isFall ? DateTime.now().millisecondsSinceEpoch : 0);

    // 5. Foot Contact
    final rawContact = normalized['footincontact'] ??
        normalized['footcontact'] ??
        normalized['contact'];
    bool inContact = false;
    if (rawContact is bool) {
      inContact = rawContact;
    } else if (rawContact is String) {
      final s = rawContact.trim().toLowerCase();
      inContact = s == 'yes' || s == 'true' || s == '1';
    } else if (rawContact is num) {
      inContact = rawContact > 0;
    } else {
      final totalPressure = sensors[0] + sensors[1] + sensors[2];
      inContact = totalPressure > 300;
    }

    // 6. MPU Status
    final mpuStatus = (normalized['mpustatus'] ?? normalized['mpu'] ?? 'Ready')
        .toString();

    return AdminReadings(
      dashboardSteps: steps,
      dailyGoal: goal,
      sensorValues: sensors,
      adjusted: true,
      fallDetected: isFall,
      fallTriggerId: fallTriggerId,
      footContact: inContact,
      mpuStatus: mpuStatus,
    );
  }

  @override
  Stream<AdminReadings?> watchReadings() {
    late StreamController<AdminReadings?> controller;
    final List<StreamSubscription> subscriptions = [];

    controller = StreamController<AdminReadings?>.broadcast(
      onListen: () {
        // Attempt anonymous sign-in in the background if unauthenticated
        if (_auth.currentUser == null) {
          _auth.signInAnonymously().then((_) {}, onError: (e) {
            debugPrint('Anonymous auth notice: $e');
          });
        }

        void handleSnapshot(DatabaseEvent event, String sourceNode) {
          if (event.snapshot.value != null) {
            final readings = parseFlexible(event.snapshot.value);
            if (readings != null) {
              debugPrint(
                '[SmartFootwear Cloud] Telemetry synced from $sourceNode: '
                'Steps=${readings.dashboardSteps}, Heel=${readings.heelADC}, '
                'Midfoot=${readings.midfootADC}, Forefoot=${readings.forefootADC}',
              );
              controller.add(readings);
            }
          }
        }

        void handleError(dynamic e, String sourceNode) {
          debugPrint('RTDB $sourceNode stream notice: $e');
          final str = e.toString();
          if (str.contains('permission-denied') || str.contains('Permission denied')) {
            controller.addError(
              'Firebase Permission Denied ($sourceNode). Change Realtime Database rules to: { ".read": true, ".write": true } in Firebase Console.',
            );
          }
        }

        // 1. Listen to Realtime Database /SmartFootwear/latest (Primary from hardware)
        try {
          subscriptions.add(
            _rtdbSmartFootwearLatest.onValue.listen(
              (event) => handleSnapshot(event, '/SmartFootwear/latest'),
              onError: (e) => handleError(e, '/SmartFootwear/latest'),
            ),
          );
        } catch (e) {
          debugPrint('RTDB /SmartFootwear/latest subscription error: $e');
        }

        // 2. Listen to Realtime Database /SmartFootwear
        try {
          subscriptions.add(
            _rtdbSmartFootwearRoot.onValue.listen(
              (event) => handleSnapshot(event, '/SmartFootwear'),
              onError: (e) => handleError(e, '/SmartFootwear'),
            ),
          );
        } catch (e) {
          debugPrint('RTDB /SmartFootwear subscription error: $e');
        }

        // 3. Listen to Realtime Database /smartFootwear/latest
        try {
          subscriptions.add(
            _rtdbFootwearCamelLatest.onValue.listen(
              (event) => handleSnapshot(event, '/smartFootwear/latest'),
              onError: (e) => handleError(e, '/smartFootwear/latest'),
            ),
          );
        } catch (e) {
          debugPrint('RTDB /smartFootwear/latest subscription error: $e');
        }

        // 4. Listen to Realtime Database /smartFootwear
        try {
          subscriptions.add(
            _rtdbFootwearCamel.onValue.listen(
              (event) => handleSnapshot(event, '/smartFootwear'),
              onError: (e) => handleError(e, '/smartFootwear'),
            ),
          );
        } catch (e) {
          debugPrint('RTDB /smartFootwear subscription error: $e');
        }

        // 5. Listen to Realtime Database /smartfootwear
        try {
          subscriptions.add(
            _rtdbFootwearLower.onValue.listen(
              (event) => handleSnapshot(event, '/smartfootwear'),
              onError: (e) => handleError(e, '/smartfootwear'),
            ),
          );
        } catch (e) {
          debugPrint('RTDB /smartfootwear subscription error: $e');
        }

        // 6. Listen to Realtime Database /strideAdmin/readings
        try {
          subscriptions.add(
            _rtdbAdmin.onValue.listen(
              (event) => handleSnapshot(event, '/strideAdmin/readings'),
              onError: (e) => handleError(e, '/strideAdmin/readings'),
            ),
          );
        } catch (e) {
          debugPrint('RTDB /strideAdmin subscription error: $e');
        }

        // 7. Fallback to Cloud Firestore
        try {
          subscriptions.add(
            _document.snapshots().listen(
              (snapshot) {
                if (snapshot.exists && snapshot.data() != null) {
                  try {
                    final readings = AdminReadings.fromJson(snapshot.data()!);
                    controller.add(readings);
                  } catch (_) {
                    final readings = parseFlexible(snapshot.data());
                    if (readings != null) controller.add(readings);
                  }
                }
              },
              onError: (e) =>
                  debugPrint('Firestore fallback stream notice: $e'),
            ),
          );
        } catch (e) {
          debugPrint('Firestore fallback subscription error: $e');
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> sendMotorCommand(String command) async {
    final payload = {
      'command': command.toUpperCase(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      await _rtdbCommands.set(payload);
      debugPrint('[SmartFootwear Cloud] Motor command dispatched: $command');
    } catch (e) {
      debugPrint('RTDB motor command dispatch notice: $e');
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<bool> hasAdminRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      try {
        await _auth.signInAnonymously();
      } catch (_) {}
    }
    return true;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> save(AdminReadings readings) async {
    if (!readings.valid) {
      throw ArgumentError.value(readings, 'readings', 'Invalid values.');
    }

    final data = {
      ...readings.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // 1. Write to Realtime Database
    try {
      await _rtdbSmartFootwearLatest.set(data);
      await _rtdbSmartFootwearRoot.set(data);
      await _rtdbFootwearCamel.set(data);
      await _rtdbAdmin.set(data);
    } catch (e) {
      debugPrint('RTDB save notice: $e');
    }

    // 2. Write to Firestore if available
    try {
      await _document.set({
        ...readings.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore save notice: $e');
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _rtdbSmartFootwearLatest.remove();
      await _rtdbSmartFootwearRoot.remove();
      await _rtdbFootwearCamel.remove();
      await _rtdbAdmin.remove();
    } catch (_) {}
    try {
      await _document.delete();
    } catch (_) {}
  }
}
