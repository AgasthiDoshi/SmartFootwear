import 'dart:math' as math;
import 'sensor.dart';

/// Hysteresis + refractory gate prevent repeated counts during one contact.
class StepDetector {
  int steps = 0;
  bool _contact = false;
  int? _lastStep;
  final List<int> _intervals = [];
  static const highThreshold = 700.0;
  static const lowThreshold = 150.0;
  bool add(SensorFrame frame) {
    final pressure = frame.values.take(3).reduce((a, b) => a + b);
    if (pressure < lowThreshold) {
      _contact = false;
    }
    if (!_contact && pressure >= highThreshold) {
      _contact = true;
      if (_lastStep == null || frame.milliseconds - _lastStep! >= 300) {
        if (_lastStep != null) {
          final gap = frame.milliseconds - _lastStep!;
          if (gap <= 2000) {
            _intervals.add(gap);
          } else {
            _intervals.clear();
          }
          if (_intervals.length > 8) {
            _intervals.removeAt(0);
          }
        }
        _lastStep = frame.milliseconds;
        steps++;
        return true;
      }
    }
    return false;
  }

  /// Drop the edge and interval across a pause or signal gap.
  void breakContinuity() {
    _contact = true;
    _lastStep = null;
    _intervals.clear();
  }

  double? cadenceAt(int milliseconds) =>
      _lastStep == null ||
          milliseconds - _lastStep! > 2000 ||
          _intervals.isEmpty
      ? null
      : 60000 / (_intervals.reduce((a, b) => a + b) / _intervals.length);
  double? get consistency {
    if (_intervals.length < 3) {
      return null;
    }
    final mean = _intervals.reduce((a, b) => a + b) / _intervals.length;
    final variance =
        _intervals.fold<double>(0, (s, v) => s + math.pow(v - mean, 2)) /
        _intervals.length;
    return (100 * (1 - math.sqrt(variance) / mean)).clamp(0, 100).toDouble();
  }
}

/// Constant-space online statistics; charts retain only their last 120 samples.
class GaitAccumulator {
  int samples = 0;
  final List<double> totals = [0, 0, 0];
  void add(SensorFrame frame) {
    samples++;
    for (var i = 0; i < 3; i++) {
      totals[i] += frame.values[i];
    }
  }

  List<double> get shares {
    final sum = totals.reduce((a, b) => a + b);
    return List.generate(3, (i) => sum == 0 ? 0 : totals[i] / sum * 100);
  }
}
