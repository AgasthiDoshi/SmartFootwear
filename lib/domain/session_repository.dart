import 'dart:convert';
import 'replay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordedSession {
  const RecordedSession({
    required this.id,
    required this.startedAt,
    required this.activeMilliseconds,
    required this.steps,
    required this.pressureShares,
    required this.calibrated,
    required this.consistency,
    this.replay = const [],
  });
  final String id;
  final DateTime startedAt;
  final int activeMilliseconds, steps;
  final List<double> pressureShares;
  final bool calibrated;
  final double? consistency;
  final List<ReplayPoint> replay;
  double get cadence =>
      activeMilliseconds == 0 ? 0 : steps * 60000 / activeMilliseconds;
  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'activeMs': activeMilliseconds,
    'steps': steps,
    'shares': pressureShares,
    'calibrated': calibrated,
    'consistency': consistency,
    'source': 'demo',
    'replay': replay.map((p) => p.toJson()).toList(),
  };
  factory RecordedSession.fromJson(Map<String, dynamic> json) {
    final shares = (json['shares'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final replay = ((json['replay'] as List?) ?? [])
        .map((p) => ReplayPoint.fromJson(p as Map<String, dynamic>))
        .toList();
    final ms = json['activeMs'] as int;
    final steps = json['steps'] as int;
    final consistency = (json['consistency'] as num?)?.toDouble();
    final id = json['id'] as String;
    final shareSum = shares.fold<double>(0, (sum, value) => sum + value);
    if (id.trim().isEmpty ||
        (shareSum != 0 && (shareSum - 100).abs() > .01) ||
        (ms == 0 && steps > 0) ||
        json['source'] != 'demo' ||
        shares.length != 3 ||
        shares.any((v) => !v.isFinite || v < 0 || v > 100) ||
        ms < 0 ||
        steps < 0 ||
        (consistency != null &&
            (!consistency.isFinite || consistency < 0 || consistency > 100))) {
      throw const FormatException('Invalid session');
    }
    if (replay.length > ReplayRecorder.capacity) {
      throw const FormatException('Replay too large');
    }
    var previousMs = -1, previousSteps = 0;
    for (final p in replay) {
      if (p.activeMilliseconds <= previousMs ||
          p.activeMilliseconds > ms ||
          p.steps < previousSteps ||
          p.steps > steps) {
        throw const FormatException('Invalid replay sequence');
      }
      previousMs = p.activeMilliseconds;
      previousSteps = p.steps;
    }
    return RecordedSession(
      id: id,
      startedAt: DateTime.parse(json['startedAt'] as String),
      activeMilliseconds: ms,
      steps: steps,
      pressureShares: List.unmodifiable(shares),
      calibrated: json['calibrated'] as bool,
      consistency: consistency,
      replay: List.unmodifiable(replay),
    );
  }
}

abstract interface class SessionRepository {
  Future<List<RecordedSession>> load();
  Future<void> save(List<RecordedSession> sessions);
}

class LocalSessionRepository implements SessionRepository {
  static const key = 'stride.demo.sessions.v1';
  @override
  Future<List<RecordedSession>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null) {
      return [];
    }
    final sessions = (jsonDecode(raw) as List)
        .map((v) => RecordedSession.fromJson(v as Map<String, dynamic>))
        .toList();
    if (sessions.length > 100 ||
        sessions.map((s) => s.id).toSet().length != sessions.length) {
      throw const FormatException('Invalid session history');
    }
    return sessions;
  }

  @override
  Future<void> save(List<RecordedSession> sessions) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      key,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    )) {
      throw StateError('Session storage unavailable');
    }
  }
}
