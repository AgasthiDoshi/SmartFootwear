import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/domain/admin_readings.dart';
import 'package:stride_ai/domain/admin_readings_repository.dart';
import 'package:stride_ai/domain/sensor.dart';
import 'package:stride_ai/services/admin_readings_controller.dart';

void main() {
  test('admin readings validate and serialize bounded sensor values', () {
    const readings = AdminReadings(
      dashboardSteps: 9000,
      dailyGoal: 10000,
      sensorValues: [100, 200, 300, 0.1, -0.2, 1, 5, -6, 7],
    );

    expect(readings.valid, isTrue);
    expect(
      AdminReadings.fromJson(readings.toJson()).sensorValues,
      readings.sensorValues,
    );
    expect(
      readings
          .copyWith(sensorValues: [5000, ...SensorFrame.resting.skip(1)])
          .valid,
      isFalse,
    );
  });

  test(
    'shared overrides reach dashboard and live simulated channels',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = _MemoryAdminRepository();
      final admin = AdminReadingsController(repository: repository);
      final app = AppController(adminReadings: admin);
      await app.refresh();
      await admin.signIn('admin@example.test', 'not-a-real-password');

      const adjusted = AdminReadings(
        dashboardSteps: 7200,
        dailyGoal: 9000,
        sensorValues: [100, 200, 300, 0.1, -0.2, 1, 5, -6, 7],
      );
      expect(await admin.save(adjusted), isTrue);
      expect(app.dashboardData?.steps, 7200);
      expect(app.dashboardData?.goal, 9000);
      expect(app.studio.sensorOverrides, adjusted.sensorValues);

      app.studio.startFeed(automatic: false);
      app.studio.tick();
      expect(app.studio.latest?.values, adjusted.sensorValues);
      expect(await admin.reset(), isTrue);
      expect(app.dashboardData?.steps, 6420);
      expect(app.studio.sensorOverrides, isNull);
      expect(app.studio.latest, isNull);
      app.dispose();
      await repository.dispose();
    },
  );

  testWidgets('four quick Profile taps open Firebase admin sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final controller = AppController();
    await controller.restore();
    await tester.pumpWidget(StrideApp(controller: controller));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
    }

    expect(find.text('Admin access'), findsOneWidget);
    expect(find.text('Firebase setup required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryAdminRepository implements AdminReadingsRepository {
  final _updates = StreamController<AdminReadings?>.broadcast(sync: true);
  bool signedIn = false;
  AdminReadings? current;

  @override
  String? get currentUserEmail => signedIn ? 'admin@example.test' : null;

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<AdminReadings?> watchReadings() => _updates.stream;

  @override
  Future<void> signIn(String email, String password) async {
    signedIn = true;
  }

  @override
  Future<bool> hasAdminRole() async => signedIn;

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<void> save(AdminReadings readings) async {
    current = readings;
    _updates.add(readings);
  }

  @override
  Future<void> reset() async {
    current = null;
    _updates.add(null);
  }

  @override
  Future<void> sendMotorCommand(String command) async {}

  Future<void> dispose() => _updates.close();
}
