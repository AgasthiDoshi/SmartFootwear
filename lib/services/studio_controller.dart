import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/sensor.dart';
import '../domain/replay.dart';
import '../domain/gait_processing.dart';
import '../domain/session_repository.dart';

enum SessionPhase { idle, recording, paused, saving, unsaved }

class StudioController extends ChangeNotifier {
  StudioController({
    SensorSource? source,
    SessionRepository? repository,
    DateTime Function()? clock,
  }) : source = source ?? DemoSensorSource(),
       repository = repository ?? LocalSessionRepository(),
       clock = clock ?? DateTime.now;
  final SensorSource source;
  final SessionRepository repository;
  final DateTime Function() clock;
  static const chartCapacity = 120;
  Timer? _timer;
  bool running = false,
      connected = true,
      historyLoading = true,
      calibrated = false;
  String? historyError, saveError;
  String calibrationMessage = 'Factory baseline · calibration optional';
  MotionPattern pattern = MotionPattern.walking;
  SessionPhase phase = SessionPhase.idle;
  SensorCalibration calibration = SensorCalibration.identity;
  SensorFrame? latest;
  List<double>? sensorOverrides;
  final List<SensorFrame> _chart = [];
  List<SensorFrame> get chart => List.unmodifiable(_chart);
  final List<SensorFrame> _calibrationFrames = [];
  bool calibrating = false;
  double get calibrationProgress => _calibrationFrames.length / 40;
  List<RecordedSession> _sessions = [];
  List<RecordedSession> get sessions => List.unmodifiable(_sessions);
  RecordedSession? pending, lastSaved;
  StepDetector detector = StepDetector();
  GaitAccumulator gait = GaitAccumulator();
  int activeMilliseconds = 0;
  ReplayRecorder _replay = ReplayRecorder();
  bool retainReplay = true;
  bool _captureReplay = true;
  DateTime? _startedAt;
  MotionPattern? _beforeCalibration;
  bool _disposed = false;
  bool _loadingHistory = false;
  String? _sessionId;
  double? get cadence =>
      latest == null ? null : detector.cadenceAt(latest!.milliseconds);
  bool get canStart =>
      phase == SessionPhase.idle &&
      connected &&
      !calibrating &&
      !historyLoading &&
      historyError == null;
  bool get sessionActive =>
      phase == SessionPhase.recording || phase == SessionPhase.paused;

  void setSensorOverrides(List<double>? values, {int? stepCount}) {
    final wasOverridden = sensorOverrides != null;
    sensorOverrides = values == null ? null : List.unmodifiable(values);
    if (sensorOverrides == null && wasOverridden) {
      latest = null;
      _chart.clear();
    } else if (sensorOverrides != null) {
      final nowMs = clock().millisecondsSinceEpoch;
      latest = SensorFrame(nowMs, sensorOverrides!);
      _chart.add(latest!);
      if (_chart.length > chartCapacity) {
        _chart.removeAt(0);
      }
      if (stepCount != null && stepCount > 0) {
        detector.steps = stepCount;
      }
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    if (phase != SessionPhase.idle || _loadingHistory) {
      return;
    }
    _loadingHistory = true;
    historyLoading = true;
    historyError = null;
    notifyListeners();
    try {
      _sessions = await repository.load();
    } catch (_) {
      historyError =
          'Could not read saved sessions. Retry before recording to protect existing history.';
    }
    historyLoading = false;
    _loadingHistory = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  void startFeed({bool automatic = true}) {
    if (!connected ||
        running ||
        phase == SessionPhase.saving ||
        phase == SessionPhase.unsaved) {
      return;
    }
    running = true;
    if (automatic) {
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => tick());
    }
    notifyListeners();
  }

  void stopFeed() {
    _timer?.cancel();
    _timer = null;
    running = false;
    if (phase == SessionPhase.recording) {
      phase = SessionPhase.paused;
      detector.breakContinuity();
    }
    if (calibrating) {
      _finishCalibration(cancelled: true);
    }
    notifyListeners();
  }

  /// Public clock step allows deterministic tests without real timers.
  void tick() {
    if (!running || !connected) {
      return;
    }
    final raw = source.next(pattern);
    if (calibrating) {
      _calibrationFrames.add(raw);
      if (_calibrationFrames.length == 40) {
        calibration = SensorCalibration.fromRest(_calibrationFrames);
        calibrated = true;
        _finishCalibration();
        _chart.clear();
      }
    }
    final baselineFrame = calibration.apply(raw);
    final overrides = sensorOverrides;
    latest = overrides == null
        ? baselineFrame
        : SensorFrame(baselineFrame.milliseconds, List.unmodifiable(overrides));
    _chart.add(latest!);
    if (_chart.length > chartCapacity) {
      _chart.removeAt(0);
    }
    if (phase == SessionPhase.recording) {
      activeMilliseconds += DemoSensorSource.sampleMilliseconds;
      detector.add(latest!);
      gait.add(latest!);
      if (_captureReplay) {
        _replay.add(activeMilliseconds, detector.steps, latest!);
      }
    }
    notifyListeners();
  }

  void setPattern(MotionPattern value) {
    if (calibrating) {
      return;
    }
    pattern = value;
    if (sessionActive) {
      detector.breakContinuity();
    }
    notifyListeners();
  }

  void calibrate({bool automatic = true}) {
    if (sessionActive ||
        calibrating ||
        !connected ||
        phase != SessionPhase.idle) {
      return;
    }
    _beforeCalibration = pattern;
    pattern = MotionPattern.stationary;
    _calibrationFrames.clear();
    calibrating = true;
    calibrationMessage = 'Collecting 40 unloaded, stationary samples…';
    startFeed(automatic: automatic);
    notifyListeners();
  }

  void _finishCalibration({bool cancelled = false}) {
    calibrating = false;
    pattern = _beforeCalibration ?? MotionPattern.walking;
    calibrationMessage = cancelled
        ? 'Calibration cancelled; previous baseline retained.'
        : 'Calibrated · FSR zeroed, gravity retained at 1 g';
    _calibrationFrames.clear();
  }

  void resetCalibration() {
    if (phase != SessionPhase.idle || calibrating) {
      return;
    }
    calibration = SensorCalibration.identity;
    calibrated = false;
    _chart.clear();
    latest = null;
    calibrationMessage = 'Factory baseline · calibration optional';
    notifyListeners();
  }

  void setConnected(bool value) {
    connected = value;
    if (!value) {
      stopFeed();
      latest = null;
      _chart.clear();
    }
    notifyListeners();
  }

  void startSession({bool automatic = true}) {
    if (!canStart) {
      return;
    }
    detector = StepDetector();
    gait = GaitAccumulator();
    activeMilliseconds = 0;
    _replay = ReplayRecorder();
    _captureReplay = retainReplay;
    _startedAt = clock();
    final baseId = 'demo-${_startedAt!.microsecondsSinceEpoch}';
    var suffix = 0;
    do {
      _sessionId = '$baseId-${suffix++}';
    } while (_sessions.any((s) => s.id == _sessionId));
    lastSaved = null;
    saveError = null;
    phase = SessionPhase.recording;
    startFeed(automatic: automatic);
    notifyListeners();
  }

  void pause() {
    if (phase != SessionPhase.recording) {
      return;
    }
    phase = SessionPhase.paused;
    detector.breakContinuity();
    notifyListeners();
  }

  void resume({bool automatic = true}) {
    if (phase != SessionPhase.paused || !connected) {
      return;
    }
    detector.breakContinuity();
    phase = SessionPhase.recording;
    startFeed(automatic: automatic);
    notifyListeners();
  }

  Future<void> stop() async {
    if (!sessionActive) {
      return;
    }
    // Freeze the summary before any asynchronous write or further sample.
    final started = _startedAt!;
    pending = RecordedSession(
      id: _sessionId!,
      startedAt: started,
      activeMilliseconds: activeMilliseconds,
      steps: detector.steps,
      pressureShares: List.unmodifiable(gait.shares),
      calibrated: calibrated,
      consistency: detector.consistency,
      replay: _captureReplay ? _replay.finish() : const [],
    );
    _timer?.cancel();
    _timer = null;
    running = false;
    await retrySave();
  }

  Future<void> retrySave() async {
    if (pending == null || phase == SessionPhase.saving) {
      return;
    }
    phase = SessionPhase.saving;
    saveError = null;
    notifyListeners();
    final next = [
      pending!,
      ..._sessions.where((s) => s.id != pending!.id),
    ].take(100).toList();
    try {
      await repository.save(next);
      _sessions = next;
      lastSaved = pending;
      pending = null;
      phase = SessionPhase.idle;
    } catch (_) {
      phase = SessionPhase.unsaved;
      saveError =
          'Session not saved. Keep the app open and retry. Your summary is retained in memory.';
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> deleteSession(String id) async {
    if (phase != SessionPhase.idle || historyLoading || historyError != null) {
      return false;
    }
    phase = SessionPhase.saving;
    notifyListeners();
    final next = _sessions.where((s) => s.id != id).toList();
    try {
      await repository.save(next);
      _sessions = next;
      saveError = null;
      phase = SessionPhase.idle;
      if (!_disposed) {
        notifyListeners();
      }
      return true;
    } catch (_) {
      saveError = 'Could not delete session. History is unchanged.';
      phase = SessionPhase.idle;
      if (!_disposed) {
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
