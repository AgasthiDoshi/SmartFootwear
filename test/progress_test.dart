import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/domain/progress.dart';
import 'package:stride_ai/domain/progress_repository.dart';
import 'package:stride_ai/domain/session_repository.dart';
import 'package:stride_ai/domain/replay.dart';
import 'package:stride_ai/domain/sensor.dart';
import 'package:stride_ai/domain/csv_export.dart';
import 'package:stride_ai/services/progress_controller.dart';
import 'package:stride_ai/services/replay_controller.dart';
import 'helpers/progress_fixtures.dart';

void main() {
  test(
    'daily buckets include local midnight and exclude next-day boundary',
    () {
      final window = TrendWindow(
        [
          savedSession(id: 'a', date: DateTime(2026, 10, 21), steps: 50),
          savedSession(
            id: 'b',
            date: DateTime(2026, 10, 21, 23, 59),
            steps: 80,
          ),
          savedSession(id: 'c', date: DateTime(2026, 10, 22), steps: 400),
        ],
        TrendPeriod.daily,
        DateTime(2026, 10, 21),
      );
      expect(window.buckets.length, 7);
      expect(window.buckets.last.totals.steps, 130);
      expect(window.buckets.first.totals.steps, 0);
      expect(window.totals.sessions, 2);
    },
  );
  test(
    'weekly Monday buckets and monthly leap/year boundaries are correct',
    () {
      final weekly = TrendWindow(
        [savedSession(date: DateTime(2026, 10, 19))],
        TrendPeriod.weekly,
        DateTime(2026, 10, 21),
      );
      expect(weekly.buckets.length, 8);
      expect(weekly.buckets.last.start.weekday, DateTime.monday);
      expect(weekly.buckets.last.totals.sessions, 1);
      final monthly = TrendWindow(
        [savedSession(date: DateTime(2024, 2, 29, 23, 59))],
        TrendPeriod.monthly,
        DateTime(2024, 3, 1),
      );
      expect(monthly.buckets.length, 6);
      expect(monthly.buckets[4].start, DateTime(2024, 2));
      expect(monthly.buckets[4].totals.sessions, 1);
      expect(monthly.buckets.first.start, DateTime(2023, 10));
    },
  );
  test(
    'aggregate cadence is time weighted and zero duration is unavailable',
    () {
      final total = SessionTotals.from([
        savedSession(id: 'a', steps: 100, ms: 60000),
        savedSession(id: 'b', steps: 600, ms: 120000),
      ]);
      expect(total.cadence, closeTo(233.333333, .001));
      expect(total.minutes, 3);
      expect(SessionTotals.from([]).cadence, isNull);
    },
  );
  test(
    'achievements derive only from retained sessions and distinct dates',
    () {
      expect(Achievement.evaluate([]).every((a) => !a.unlocked), isTrue);
      final sessions = [
        for (var i = 0; i < 3; i++)
          savedSession(id: '$i', date: DateTime(2026, 10, 19 + i), steps: 400),
      ];
      expect(Achievement.evaluate(sessions).every((a) => a.unlocked), isTrue);
      sessions.removeLast();
      expect(Achievement.evaluate(sessions).last.unlocked, isFalse);
    },
  );
  test(
    'goals and quest enrollment persist across controller recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 21, 12);
      final c = ProgressController(clock: () => now);
      addTearDown(c.dispose);
      await c.load();
      expect(
        await c.setGoals(const PersonalGoals(dailySteps: 250, dailyMinutes: 4)),
        isTrue,
      );
      expect(await c.join(QuestKind.hundredSteps, [savedSession()]), isTrue);
      final restored = ProgressController();
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.goals.dailySteps, 250);
      expect(restored.goals.dailyMinutes, 4);
      expect(restored.quest!.joinedAt, now);
      expect(restored.quest!.excludedIds, ['demo-test']);
    },
  );
  test(
    'invalid goals, read errors and failed writes protect prior preferences',
    () async {
      final repository = MemoryProgress()..failLoad = true;
      final c = ProgressController(repository: repository);
      addTearDown(c.dispose);
      await c.load();
      expect(c.editable, isFalse);
      expect(await c.setGoals(const PersonalGoals(dailySteps: 200)), isFalse);
      repository.failLoad = false;
      await c.load();
      repository.failSave = true;
      expect(await c.setGoals(const PersonalGoals(dailySteps: 200)), isFalse);
      expect(c.goals.dailySteps, 1000);
      expect(c.saveError, isNotNull);
      expect(await c.setGoals(const PersonalGoals(dailyMinutes: 0)), isFalse);
      repository.failSave = false;
      expect(await c.setGoals(const PersonalGoals(dailySteps: 200)), isTrue);
    },
  );
  test(
    'quest excludes pre-join and existing future-dated records and responds to deletion',
    () {
      final joined = DateTime(2026, 10, 21, 12);
      final q = QuestEnrollment(
        kind: QuestKind.hundredSteps,
        joinedAt: joined,
        excludedIds: const ['existing'],
      );
      final sessions = [
        savedSession(
          id: 'before',
          date: DateTime(2026, 10, 21, 11),
          steps: 1000,
        ),
        savedSession(id: 'existing', date: DateTime(2027), steps: 1000),
        savedSession(id: 'new', date: DateTime(2026, 10, 21, 13), steps: 100),
      ];
      expect(q.value(sessions), 100);
      expect(q.progress(sessions), 1);
      sessions.removeLast();
      expect(q.progress(sessions), 0);
    },
  );
  test(
    'minute and walking-ritual quests use active time and nonzero contacts',
    () {
      final sessions = [
        savedSession(id: 'zero', steps: 0, ms: 60000),
        savedSession(id: 'walk', ms: 240000),
      ];
      final minutes = QuestEnrollment(
        kind: QuestKind.fiveMinutes,
        joinedAt: DateTime(2026),
        excludedIds: const [],
      );
      final ritual = QuestEnrollment(
        kind: QuestKind.threeWalks,
        joinedAt: DateTime(2026),
        excludedIds: const [],
      );
      expect(minutes.progress(sessions), 1);
      expect(minutes.displayValue(sessions), '5.0');
      expect(ritual.value(sessions), 1);
    },
  );
  test(
    'replay recorder is bounded, preserves endpoints and stores observed values',
    () {
      final recorder = ReplayRecorder();
      for (var ms = 50; ms <= 600000; ms += 50) {
        recorder.add(
          ms,
          ms ~/ 600,
          const SensorFrame(0, [123.456789, 0, 0, .1, 0, 1, 0, 0, 0]),
        );
      }
      final points = recorder.finish();
      expect(points.length, lessThanOrEqualTo(180));
      expect(points.first.activeMilliseconds, 50);
      expect(points.last.activeMilliseconds, 600000);
      expect(points.first.values.first, 123.457);
      for (var i = 1; i < points.length; i++) {
        expect(
          points[i].activeMilliseconds,
          greaterThan(points[i - 1].activeMilliseconds),
        );
      }
    },
  );
  test(
    'replay seek uses earlier checkpoint; playback is clamped, speed-aware and replayable',
    () {
      final c = ReplayController(savedSession(replay: true, ms: 1000).replay);
      addTearDown(c.dispose);
      c.seek(600);
      expect(c.observation!.activeMilliseconds, 50);
      c.setSpeed(2);
      c.play(automatic: false);
      c.advance(100);
      expect(c.position, 800);
      c.advance(100);
      expect(c.position, 1000);
      expect(c.playing, isFalse);
      c.play(automatic: false);
      expect(c.position, 50);
      c.seek(-99);
      expect(c.position, 50);
      expect(c.playing, isFalse);
    },
  );
  test(
    'session schema supports old summaries and validates persisted replay sequences',
    () {
      final original = savedSession(replay: true);
      expect(RecordedSession.fromJson(original.toJson()).replay.length, 2);
      final legacy = original.toJson()..remove('replay');
      expect(RecordedSession.fromJson(legacy).replay, isEmpty);
      final malformed = original.toJson()
        ..['replay'] = [
          original.replay.last.toJson(),
          original.replay.first.toJson(),
        ];
      expect(() => RecordedSession.fromJson(malformed), throwsFormatException);
    },
  );
  test(
    'CSV handles empty history, escaping, UTC, formula IDs and unavailable values',
    () {
      expect(sessionsCsv([]).split('\r\n').length, 2);
      final csv = sessionsCsv([savedSession(id: '=SUM(1,2)"\nnext', ms: 0)]);
      expect(csv, contains('"\'=SUM(1,2)""\nnext"'));
      expect(csv, contains('"simulated"'));
      expect(csv, contains('Z"'));
      expect(csv, contains('"0.000","",""'));
      expect(csv.endsWith('\r\n'), isTrue);
    },
  );
  test('progress repository rejects corrupt saved preferences', () async {
    SharedPreferences.setMockInitialValues({
      LocalProgressRepository.key: 'broken',
    });
    final c = ProgressController();
    addTearDown(c.dispose);
    await c.load();
    expect(c.loadError, isNotNull);
    expect(c.editable, isFalse);
  });
}
