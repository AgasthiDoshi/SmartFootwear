import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/services/admin_readings_controller.dart';
import 'package:stride_ai/services/firebase_admin_readings_repository.dart';

void main() {
  test('parseFlexible parses ESP32 hardware footwear serial monitor format', () {
    final rawData = {
      'Heel ADC': 0,
      'Midfoot ADC': 3224,
      'Forefoot ADC': 2540,
      'Acceleration (g)': 0.96,
      'Gyroscope (dps)': 4.79,
      'Fall detected': 'NO',
      'Foot contact': 'YES',
      'Steps': 29,
    };

    final readings = FirebaseAdminReadingsRepository.parseFlexible(rawData);
    expect(readings, isNotNull);
    expect(readings!.dashboardSteps, 29);
    expect(readings.dailyGoal, 8000);
    expect(readings.fallDetected, isFalse);
    expect(readings.sensorValues[0], 0.0);    // Heel
    expect(readings.sensorValues[1], 2540.0); // Forefoot
    expect(readings.sensorValues[2], 3224.0); // Midfoot/Toe
    expect(readings.sensorValues[5], 0.96);   // Accel
    expect(readings.sensorValues[8], 4.79);   // Gyro
  });

  test('parseFlexible parses SmartFootwear/latest database format', () {
    final rawData = {
      'acceleration_g': 0.98,
      'esp32_online': true,
      'fall_detected': false,
      'foot_in_contact': true,
      'forefoot_adc': 3200,
      'gyroscope_dps': 4.75,
      'heel_adc': 3850,
      'midfoot_adc': 2100,
      'mpu_status': 'Ready',
      'step_count': 35,
      'uptime_ms': 1793190003,
    };

    final readings = FirebaseAdminReadingsRepository.parseFlexible(rawData);
    expect(readings, isNotNull);
    expect(readings!.dashboardSteps, 35);
    expect(readings.heelADC, 3850);
    expect(readings.forefootADC, 3200);
    expect(readings.midfootADC, 2100);
    expect(readings.accelerationG, 0.98);
    expect(readings.gyroscopeDPS, 4.75);
    expect(readings.footContact, isTrue);
    expect(readings.fallDetected, isFalse);
    expect(readings.mpuStatus, 'Ready');
  });

  test('parseFlexible handles stringified JSON and nested SmartFootwear maps', () {
    final jsonString = jsonEncode({
      'SmartFootwear': {
        'latest': {
          'step_count': 102,
          'heel_adc': 4000,
          'midfoot_adc': 2500,
          'forefoot_adc': 1800,
          'acceleration_g': 0.99,
          'gyroscope_dps': 5.2,
          'fall_detected': false,
          'foot_in_contact': true,
        }
      }
    });

    final readings = FirebaseAdminReadingsRepository.parseFlexible(jsonString);
    expect(readings, isNotNull);
    expect(readings!.dashboardSteps, 102);
    expect(readings.heelADC, 4000);
    expect(readings.midfootADC, 2500);
    expect(readings.forefootADC, 1800);
  });

  test('hardware data updates AppController steps and Studio insole frame in real time', () {
    final admin = AdminReadingsController();
    final app = AppController(adminReadings: admin);

    final rawData = {
      'steps': 29,
      'heel': 4095,
      'midfoot': 3503,
      'forefoot': 1246,
      'accel': 0.96,
      'gyro': 4.98,
      'fall': false,
    };

    final readings = FirebaseAdminReadingsRepository.parseFlexible(rawData);
    expect(readings, isNotNull);

    admin.updateReadings(readings!);

    expect(app.dashboardData?.steps, 29);
    expect(app.studio.latest, isNotNull);
    expect(app.studio.latest!.values[0], 4095.0);
    expect(app.studio.latest!.values[1], 1246.0);
    expect(app.studio.latest!.values[2], 3503.0);
    expect(app.studio.chart.isNotEmpty, isTrue);
    expect(app.studio.detector.steps, 29);

    app.dispose();
  });
}
