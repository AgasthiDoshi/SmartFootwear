import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/domain/sensor.dart';
import 'package:stride_ai/domain/gait_processing.dart';
import 'package:stride_ai/domain/session_repository.dart';
import 'package:stride_ai/services/studio_controller.dart';

class MemorySessions implements SessionRepository {
  List<RecordedSession> data = [];
  bool failLoad = false, failSave = false;
  @override
  Future<List<RecordedSession>> load() async {
    if (failLoad) {
      throw StateError('read failed');
    }
    return List.of(data);
  }

  @override
  Future<void> save(List<RecordedSession> sessions) async {
    if (failSave) {
      throw StateError('write failed');
    }
    data = List.of(sessions);
  }
}

void main() {
  test('simulator is repeatable, resettable and within all channel ranges', () {
    final a = DemoSensorSource(), b = DemoSensorSource();
    for (var i = 0; i < 1000; i++) {
      final frame = a.next(MotionPattern.walking);
      expect(frame.values, b.next(MotionPattern.walking).values);
      expect(frame.values.length, 9);
      for (var j = 0; j < 9; j++) {
        expect(
          frame.values[j],
          inInclusiveRange(
            j < 3 ? 0 : -SensorFrame.limits[j],
            SensorFrame.limits[j],
          ),
        );
      }
    }
    a.reset();
    expect(a.next(MotionPattern.walking).milliseconds, 0);
  });
  test('calibration zeroes unloaded channels and preserves 1 g gravity', () {
    final source = DemoSensorSource();
    final rest = List.generate(
      40,
      (_) => source.next(MotionPattern.stationary),
    );
    final calibration = SensorCalibration.fromRest(rest);
    final corrected = calibration.apply(rest.first);
    for (var i = 0; i < 9; i++) {
      expect(corrected.values[i], closeTo(i == 5 ? 1 : 0, 1e-9));
    }
    expect(() => SensorCalibration.fromRest([]), throwsArgumentError);
  });
  test('20 Hz walking yields 20 contacts in 12 seconds at 100 steps/min', () {
    final source = DemoSensorSource();
    final detector = StepDetector();
    for (var i = 0; i < 240; i++) {
      detector.add(source.next(MotionPattern.walking));
    }
    expect(detector.steps, 20);
    expect(detector.cadenceAt(11950), closeTo(100, .01));
    expect(detector.consistency, 100);
    expect(detector.cadenceAt(15000), isNull);
    detector.breakContinuity();
    expect(detector.consistency, isNull);
  });
  test('stationary signal and contact bounce do not create false steps', () {
    final source = DemoSensorSource();
    final detector = StepDetector();
    for (var i = 0; i < 200; i++) {
      detector.add(source.next(MotionPattern.stationary));
    }
    expect(detector.steps, 0);
    SensorFrame f(int ms, double total) =>
        SensorFrame(ms, [total, 0, 0, 0, 0, 1, 0, 0, 0]);
    detector.add(f(10000, 900));
    detector.add(f(10050, 1000));
    detector.add(f(10100, 0));
    detector.add(f(10150, 900));
    expect(detector.steps, 1);
    detector.add(f(10500, 0));
    detector.add(f(10600, 900));
    expect(detector.steps, 2);
  });
  test(
    'stationary recording produces no contacts or invented cadence',
    () async {
      final c = StudioController(repository: MemorySessions());
      addTearDown(c.dispose);
      await c.loadHistory();
      c.setPattern(MotionPattern.stationary);
      c.startSession(automatic: false);
      for (var i = 0; i < 100; i++) {
        c.tick();
      }
      expect(c.detector.steps, 0);
      expect(c.cadence, isNull);
      expect(c.detector.consistency, isNull);
      await c.stop();
      expect(c.sessions.single.cadence, 0);
    },
  );
  test(
    'identical clock values do not overwrite sessions and retention is bounded',
    () async {
      final c = StudioController(
        repository: MemorySessions(),
        clock: () => DateTime(2026, 10, 21),
      );
      addTearDown(c.dispose);
      await c.loadHistory();
      for (var i = 0; i < 102; i++) {
        c.startSession(automatic: false);
        c.tick();
        await c.stop();
      }
      expect(c.sessions.length, 100);
      expect(c.sessions.map((s) => s.id).toSet().length, 100);
    },
  );
  test('pressure shares are normalized, zero safe, and sample weighted', () {
    final stats = GaitAccumulator();
    expect(stats.shares, [0, 0, 0]);
    stats.add(const SensorFrame(0, [100, 200, 100, 0, 0, 1, 0, 0, 0]));
    expect(stats.shares, [25, 50, 25]);
    expect(stats.samples, 1);
  });
  test(
    'calibration completes, can be cancelled, and cannot run in a session',
    () async {
      final c = StudioController(repository: MemorySessions());
      addTearDown(c.dispose);
      await c.loadHistory();
      c.calibrate(automatic: false);
      for (var i = 0; i < 40; i++) {
        c.tick();
      }
      expect(c.calibrating, isFalse);
      expect(c.calibrated, isTrue);
      expect(c.pattern, MotionPattern.walking);
      expect(c.latest!.values[5], closeTo(1, 1e-9));
      c.calibrate(automatic: false);
      c.tick();
      c.stopFeed();
      expect(c.calibrated, isTrue);
      expect(c.calibrationMessage, contains('cancelled'));
      c.resetCalibration();
      expect(c.calibrated, isFalse);
      c.startSession(automatic: false);
      c.calibrate(automatic: false);
      expect(c.calibrating, isFalse);
    },
  );
  test(
    'session pauses, disconnects, resumes, saves once and excludes paused time',
    () async {
      final repository = MemorySessions();
      final c = StudioController(repository: repository);
      addTearDown(c.dispose);
      await c.loadHistory();
      c.startSession(automatic: false);
      for (var i = 0; i < 120; i++) {
        c.tick();
      }
      expect(c.detector.steps, 10);
      expect(c.activeMilliseconds, 6000);
      c.pause();
      for (var i = 0; i < 60; i++) {
        c.tick();
      }
      expect(c.activeMilliseconds, 6000);
      expect(c.detector.steps, 10);
      c.setConnected(false);
      c.resume(automatic: false);
      expect(c.phase, SessionPhase.paused);
      c.setConnected(true);
      c.resume(automatic: false);
      for (var i = 0; i < 120; i++) {
        c.tick();
      }
      expect(c.activeMilliseconds, 12000);
      expect(c.detector.steps, 20);
      await c.stop();
      await c.stop();
      expect(c.sessions.length, 1);
      expect(c.sessions.first.steps, 20);
      expect(c.sessions.first.cadence, 100);
      expect(c.running, isFalse);
      expect(c.sessions.first.consistency, 100);
    },
  );
  test('stream chart memory is bounded at 120 frames', () async {
    final c = StudioController(repository: MemorySessions());
    addTearDown(c.dispose);
    c.startFeed(automatic: false);
    for (var i = 0; i < 1000; i++) {
      c.tick();
    }
    expect(c.chart.length, 120);
    expect(c.chart.last.milliseconds - c.chart.first.milliseconds, 5950);
    expect(() => c.chart.clear(), throwsUnsupportedError);
  });
  test(
    'failed save retains a frozen summary and retry is idempotent',
    () async {
      final repository = MemorySessions()..failSave = true;
      final c = StudioController(repository: repository);
      addTearDown(c.dispose);
      await c.loadHistory();
      c.startSession(automatic: false);
      for (var i = 0; i < 24; i++) {
        c.tick();
      }
      await c.stop();
      expect(c.phase, SessionPhase.unsaved);
      expect(c.pending!.steps, 2);
      expect(c.sessions, isEmpty);
      c.startSession();
      expect(c.phase, SessionPhase.unsaved);
      repository.failSave = false;
      await c.retrySave();
      await c.retrySave();
      expect(c.sessions.length, 1);
      expect(c.phase, SessionPhase.idle);
      expect(c.pending, isNull);
    },
  );
  test(
    'history read error blocks overwriting until successful retry',
    () async {
      final repository = MemorySessions()..failLoad = true;
      final c = StudioController(repository: repository);
      addTearDown(c.dispose);
      await c.loadHistory();
      c.startSession(automatic: false);
      expect(c.phase, SessionPhase.idle);
      expect(c.historyError, isNotNull);
      repository.failLoad = false;
      await c.loadHistory();
      expect(c.canStart, isTrue);
    },
  );
  test(
    'sessions survive controller recreation; deletion and corrupt history are handled',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = StudioController();
      addTearDown(c.dispose);
      await c.loadHistory();
      c.startSession(automatic: false);
      for (var i = 0; i < 120; i++) {
        c.tick();
      }
      await c.stop();
      final restored = StudioController();
      addTearDown(restored.dispose);
      await restored.loadHistory();
      expect(restored.sessions.single.toJson(), c.sessions.single.toJson());
      expect(await restored.deleteSession(restored.sessions.single.id), isTrue);
      expect(await LocalSessionRepository().load(), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(LocalSessionRepository.key, 'not json');
      await restored.loadHistory();
      expect(restored.historyError, isNotNull);
      expect(restored.canStart, isFalse);
    },
  );
  test('deletion failure preserves the existing session', () async {
    final repository = MemorySessions();
    final c = StudioController(repository: repository);
    addTearDown(c.dispose);
    await c.loadHistory();
    c.startSession(automatic: false);
    c.tick();
    await c.stop();
    repository.failSave = true;
    expect(await c.deleteSession(c.sessions.single.id), isFalse);
    expect(c.sessions.length, 1);
    expect(c.saveError, isNotNull);
  });
}
