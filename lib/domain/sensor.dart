import 'dart:math' as math;

/// One simulated insole. FSR values are ADC counts, not calibrated force.
class SensorFrame {
  const SensorFrame(this.milliseconds, this.values);
  final int milliseconds;

  /// Heel, forefoot, toe; acceleration X/Y/Z (g); gyro X/Y/Z (degrees/s).
  final List<double> values;
  static const labels = [
    'Heel',
    'Forefoot',
    'Toe',
    'Accel X',
    'Accel Y',
    'Accel Z',
    'Gyro X',
    'Gyro Y',
    'Gyro Z',
  ];
  static const units = [
    'ADC',
    'ADC',
    'ADC',
    'g',
    'g',
    'g',
    '°/s',
    '°/s',
    '°/s',
  ];
  static const limits = [
    4095.0,
    4095.0,
    4095.0,
    16.0,
    16.0,
    16.0,
    2000.0,
    2000.0,
    2000.0,
  ];
  static const resting = [24.0, 30.0, 18.0, .025, -.018, 1.04, .8, -.6, .4];
}

enum MotionPattern { walking, stationary }

abstract interface class SensorSource {
  SensorFrame next(MotionPattern pattern);
  void reset();
}

/// Fixed 20 Hz samples. No randomness or wall-clock input.
class DemoSensorSource implements SensorSource {
  int _tick = 0;
  static const sampleMilliseconds = 50;
  @override
  void reset() => _tick = 0;
  @override
  SensorFrame next(MotionPattern pattern) {
    final ms = _tick++ * sampleMilliseconds;
    final phase = (ms % 600) / 600;
    double pulse(double center) =>
        math.max(0, 1 - (phase - center).abs() / .13);
    final moving = pattern == MotionPattern.walking;
    final angle = 2 * math.pi * phase;
    final rest = SensorFrame.resting;
    return SensorFrame(
      ms,
      List.unmodifiable([
        rest[0] + (moving ? 1900 * pulse(.15) : 0),
        rest[1] + (moving ? 2300 * pulse(.32) : 0),
        rest[2] + (moving ? 1500 * pulse(.49) : 0),
        rest[3] + (moving ? .18 * math.sin(angle) : 0),
        rest[4] + (moving ? .12 * math.cos(angle) : 0),
        rest[5] + (moving ? .32 * math.sin(angle) : 0),
        rest[6] + (moving ? 42 * math.sin(angle) : 0),
        rest[7] + (moving ? 28 * math.cos(angle) : 0),
        rest[8] + (moving ? 18 * math.sin(angle + .4) : 0),
      ]),
    );
  }
}

class SensorCalibration {
  const SensorCalibration(this.offsets);
  static const identity = SensorCalibration([0, 0, 0, 0, 0, 0, 0, 0, 0]);
  final List<double> offsets;
  factory SensorCalibration.fromRest(List<SensorFrame> frames) {
    if (frames.isEmpty) {
      throw ArgumentError('Calibration needs resting samples');
    }
    return SensorCalibration(
      List.generate(
        9,
        (i) =>
            frames.fold<double>(0, (sum, f) => sum + f.values[i]) /
                frames.length -
            (i == 5 ? 1 : 0),
      ),
    );
  }
  SensorFrame apply(SensorFrame raw) => SensorFrame(
    raw.milliseconds,
    List.unmodifiable(
      List.generate(9, (i) {
        final v = raw.values[i] - offsets[i];
        return i < 3 ? v.clamp(0, 4095).toDouble() : v;
      }),
    ),
  );
}
