import 'sensor.dart';

class ReplayPoint {
  const ReplayPoint({
    required this.activeMilliseconds,
    required this.steps,
    required this.values,
  });
  final int activeMilliseconds, steps;
  final List<double> values;
  SensorFrame get frame => SensorFrame(activeMilliseconds, values);
  Map<String, Object> toJson() => {
    'ms': activeMilliseconds,
    'steps': steps,
    'values': values,
  };
  factory ReplayPoint.fromJson(Map<String, dynamic> json) {
    final values = (json['values'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final ms = json['ms'] as int, steps = json['steps'] as int;
    if (ms < 0 ||
        steps < 0 ||
        values.length != 9 ||
        values.any((v) => !v.isFinite) ||
        values.take(3).any((v) => v < 0 || v > 4095)) {
      throw const FormatException('Invalid replay checkpoint');
    }
    return ReplayPoint(
      activeMilliseconds: ms,
      steps: steps,
      values: List.unmodifiable(values),
    );
  }
}

/// Retains observations, never synthesizes a route or interpolates sensor data.
class ReplayRecorder {
  static const capacity = 180;
  final List<ReplayPoint> _points = [];
  ReplayPoint? _latest;
  int _spacing = 500;
  void add(int activeMilliseconds, int steps, SensorFrame frame) {
    final point = ReplayPoint(
      activeMilliseconds: activeMilliseconds,
      steps: steps,
      values: List.unmodifiable(
        frame.values.map((v) => (v * 1000).round() / 1000),
      ),
    );
    _latest = point;
    if (_points.isEmpty ||
        activeMilliseconds - _points.last.activeMilliseconds >= _spacing) {
      _points.add(point);
      _compact();
    }
  }

  void _compact() {
    if (_points.length <= capacity) {
      return;
    }
    final last = _points.last;
    final kept = [for (var i = 0; i < _points.length; i += 2) _points[i]];
    if (kept.last != last) {
      kept.add(last);
    }
    _points
      ..clear()
      ..addAll(kept);
    _spacing *= 2;
  }

  List<ReplayPoint> finish() {
    if (_latest != null &&
        (_points.isEmpty ||
            _points.last.activeMilliseconds != _latest!.activeMilliseconds)) {
      _points.add(_latest!);
      _compact();
    }
    return List.unmodifiable(_points);
  }
}

/// Select the nearest earlier saved observation; never infer missing values.
ReplayPoint replayPointAt(List<ReplayPoint> points, int milliseconds) {
  if (points.isEmpty) {
    throw ArgumentError('No replay observations');
  }
  var selected = points.first;
  for (final point in points) {
    if (point.activeMilliseconds > milliseconds) {
      break;
    }
    selected = point;
  }
  return selected;
}
