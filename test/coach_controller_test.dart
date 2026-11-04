import 'package:flutter_test/flutter_test.dart';
import 'package:stride_ai/domain/coach/coach_models.dart';
import 'package:stride_ai/domain/progress.dart';
import 'package:stride_ai/services/coach_controller.dart';
import 'package:stride_ai/services/progress_controller.dart';
import 'package:stride_ai/services/studio_controller.dart';
import 'helpers/coach_providers.dart';
import 'helpers/progress_fixtures.dart';
import 'sensor_processing_test.dart' show MemorySessions;

void main() {
  final now = DateTime(2026, 10, 21, 12);
  Future<CoachController> coach({
    MemorySessions? records,
    CoachProvider? provider,
    DateTime Function()? clock,
  }) async {
    final studio = StudioController(
      repository: records ?? MemorySessions(),
      clock: () => now,
    );
    final progress = ProgressController(
      repository: MemoryProgress(),
      clock: () => now,
    );
    await studio.loadHistory();
    await progress.load();
    final c = CoachController(
      studio: studio,
      progress: progress,
      provider: provider,
      clock: clock,
    );
    addTearDown(() {
      c.dispose();
      studio.dispose();
      progress.dispose();
    });
    return c;
  }

  test(
    'unsaved live samples do not count or invalidate saved-data answers',
    () async {
      final c = await coach();
      await c.ask('daily summary');
      final version = c.version;
      c.studio.startSession(automatic: false);
      for (var i = 0; i < 120; i++) {
        c.studio.tick();
      }
      expect(c.version, version);
      expect(c.snapshot().sessions, isEmpty);
      expect(c.exchanges.single.response!.kind, CoachResponseKind.insufficient);
      await c.studio.stop();
      expect(c.stale(c.exchanges.single), isTrue);
      await c.regenerate(c.exchanges.single.id);
      expect(
        c.exchanges.single.response!.text,
        contains('10 simulated contacts'),
      );
      expect(c.stale(c.exchanges.single), isFalse);
    },
  );
  test('in-flight results are marked stale after saved data changes', () async {
    final provider = DeferredCoach(), records = MemorySessions();
    final c = await coach(records: records, provider: provider);
    final pending = c.ask('daily summary');
    expect(c.busy, isTrue);
    expect(await c.ask('weekly summary'), isFalse);
    records.data.add(savedSession());
    await c.studio.loadHistory();
    provider.complete();
    await pending;
    expect(c.stale(c.exchanges.single), isTrue);
    expect(c.exchanges.single.response!.kind, CoachResponseKind.insufficient);
  });
  test(
    'clearing pending chat prevents a late response from restoring messages',
    () async {
      final provider = DeferredCoach();
      final c = await coach(provider: provider);
      final pending = c.ask('daily summary');
      c.clear();
      expect(c.busy, isFalse);
      provider.complete();
      await pending;
      expect(c.exchanges, isEmpty);
    },
  );
  test('conversation memory and input length are bounded', () async {
    final c = await coach();
    expect(await c.ask(' '), isFalse);
    expect(await c.ask('x' * 401), isFalse);
    for (var i = 0; i < 22; i++) {
      await c.ask('daily summary');
    }
    expect(c.exchanges.length, 20);
    expect(c.exchanges.first.id, 2);
    expect(() => c.exchanges.clear(), throwsUnsupportedError);
  });
  test(
    'provider failure is retryable without creating another user message',
    () async {
      final provider = FlakyCoach();
      final c = await coach(provider: provider);
      await c.ask('daily summary');
      expect(c.exchanges.single.error, isNotNull);
      expect(c.busy, isFalse);
      provider.fail = false;
      await c.regenerate(c.exchanges.single.id);
      expect(c.exchanges.single.error, isNull);
      expect(c.exchanges.single.response!.kind, CoachResponseKind.insufficient);
    },
  );
  test(
    'saved target changes invalidate prior answers and regeneration uses new goals',
    () async {
      final c = await coach();
      await c.ask('my goals');
      await c.progress.setGoals(
        const PersonalGoals(dailySteps: 250, dailyMinutes: 4),
      );
      expect(c.stale(c.exchanges.single), isTrue);
      await c.regenerate(c.exchanges.single.id);
      expect(
        c.exchanges.single.response!.text,
        contains('0/250 recorded contacts'),
      );
    },
  );
  test('local date changes invalidate yesterday snapshots', () async {
    var clock = now;
    final c = await coach(clock: () => clock);
    await c.ask('daily summary');
    clock = DateTime(2026, 10, 22, 1);
    c.refresh();
    expect(c.stale(c.exchanges.single), isTrue);
    await c.regenerate(c.exchanges.single.id);
    expect(c.exchanges.single.asOf, clock);
  });
}
