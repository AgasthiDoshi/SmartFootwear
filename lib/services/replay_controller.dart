import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/replay.dart';

class ReplayController extends ChangeNotifier {
  ReplayController(this.points)
    : position = points.isEmpty ? 0 : points.first.activeMilliseconds;
  final List<ReplayPoint> points;
  int position;
  bool playing = false;
  double speed = 1;
  Timer? _timer;
  int get min => points.isEmpty ? 0 : points.first.activeMilliseconds;
  int get max => points.isEmpty ? 0 : points.last.activeMilliseconds;
  ReplayPoint? get observation =>
      points.isEmpty ? null : replayPointAt(points, position);
  void seek(int milliseconds) {
    pause();
    position = milliseconds.clamp(min, max);
    notifyListeners();
  }

  void setSpeed(double value) {
    if ([.5, 1.0, 2.0].contains(value)) {
      speed = value;
      notifyListeners();
    }
  }

  void play({bool automatic = true}) {
    if (points.length < 2 || playing) {
      return;
    }
    if (position >= max) {
      position = min;
    }
    playing = true;
    if (automatic) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => advance(100),
      );
    }
    notifyListeners();
  }

  void advance(int elapsedMilliseconds) {
    if (!playing || elapsedMilliseconds < 0) {
      return;
    }
    position = (position + (elapsedMilliseconds * speed).round()).clamp(
      min,
      max,
    );
    if (position == max) {
      pause();
    }
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    playing = false;
    notifyListeners();
  }

  void jump(int direction) {
    if (points.isEmpty) {
      return;
    }
    final index = points.indexOf(observation!);
    if (direction < 0 && position > observation!.activeMilliseconds) {
      seek(observation!.activeMilliseconds);
      return;
    }
    seek(
      points[(index + direction).clamp(0, points.length - 1)]
          .activeMilliseconds,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String replayTime(int ms) =>
    '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
