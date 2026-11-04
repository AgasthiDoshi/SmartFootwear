import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride_ai/core/theme.dart';
import 'package:stride_ai/features/history/history_screen.dart';
import 'package:stride_ai/features/progress/goals_screen.dart';
import 'package:stride_ai/features/progress/quests_screen.dart';
import 'package:stride_ai/features/progress/trend_chart.dart';
import 'package:stride_ai/features/replay/replay_screen.dart';
import 'package:stride_ai/features/history/session_details_screen.dart';
import 'package:stride_ai/services/progress_controller.dart';
import 'package:stride_ai/services/studio_controller.dart';
import 'package:stride_ai/widgets/csv_export_dialog.dart';
import 'package:stride_ai/domain/progress.dart';
import 'helpers/progress_fixtures.dart';
import 'sensor_processing_test.dart' show MemorySessions;

class FakeCsvDelivery implements CsvDelivery {
  String? received;
  bool fail = false;
  @override
  Future<String> share(String csv, Rect origin) async {
    if (fail) {
      throw StateError('Share failed');
    }
    received = csv;
    return 'Share sheet dismissed. No destination selected.';
  }
}

void main() {
  final now = DateTime(2026, 10, 21, 12);
  Future<ProgressController> prefs({MemoryProgress? repository}) async {
    final c = ProgressController(
      repository: repository ?? MemoryProgress(),
      clock: () => now,
    );
    addTearDown(c.dispose);
    await c.load();
    return c;
  }

  Future<StudioController> studio({MemorySessions? repository}) async {
    final c = StudioController(repository: repository ?? MemorySessions());
    addTearDown(c.dispose);
    await c.loadHistory();
    return c;
  }

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(theme: strideTheme(Brightness.dark), home: child),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty history has no fake chart and CSV export is disabled', (
    tester,
  ) async {
    await mount(
      tester,
      HistoryScreen(studio: await studio(), progress: await prefs()),
    );
    expect(find.text('Your first recording starts here'), findsOneWidget);
    expect(find.byType(TrendChart), findsNothing);
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Export all saved recordings as CSV',
      ),
    );
    expect(button.onPressed, isNull);
  });
  testWidgets(
    'all trend periods switch, zero buckets filter, and history can reset',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemorySessions()..data = [savedSession()];
      await mount(
        tester,
        HistoryScreen(
          studio: await studio(repository: repository),
          progress: await prefs(),
        ),
      );
      for (final label in ['Weekly', 'Monthly', 'Daily']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final chart = tester.widget<TrendChart>(find.byType(TrendChart));
      expect(chart.window.totals.steps, 100);
      chart.onSelect(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('No saved recordings in this bucket.'),
        180,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Show all'),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(find.text('No saved recordings in this bucket.'), findsNothing);
    },
  );
  testWidgets('goals validate inputs and save locally through the repository', (
    tester,
  ) async {
    final repository = MemoryProgress();
    final progress = await prefs(repository: repository);
    await mount(
      tester,
      GoalsScreen(progress: progress, studio: await studio()),
    );
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.scrollUntilVisible(
      find.text('Save goals'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number from 1 to 100000.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '250');
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();
    expect(progress.goals.dailySteps, 250);
    expect(repository.data.goals.dailyMinutes, 4);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'quest enrollment excludes existing sessions, persists and completes on new saved data',
    (tester) async {
      final repository = MemorySessions()..data = [savedSession()];
      final c = await studio(repository: repository);
      final progressRepository = MemoryProgress();
      final progress = await prefs(repository: progressRepository);
      await mount(tester, QuestsScreen(progress: progress, studio: c));
      await tester.tap(find.text('Join quest').first);
      await tester.pumpAndSettle();
      expect(find.text('Quest in progress'), findsOneWidget);
      expect(progress.quest!.value(c.sessions), 0);
      expect(progressRepository.data.quest, isNotNull);
      repository.data.add(
        savedSession(id: 'new', date: DateTime(2026, 10, 21, 13)),
      );
      await c.loadHistory();
      await tester.pumpAndSettle();
      expect(find.text('Quest complete'), findsOneWidget);
      expect(progress.quest!.kind, QuestKind.hundredSteps);
    },
  );
  testWidgets('replay seeks saved observations, plays to end, and restarts', (
    tester,
  ) async {
    final repository = MemorySessions()
      ..data = [savedSession(replay: true, ms: 1000)];
    await mount(
      tester,
      ReplayScreen(
        studio: await studio(repository: repository),
        id: 'demo-test',
      ),
    );
    await tester.scrollUntilVisible(find.byType(Slider), 100);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(750);
    await tester.pumpAndSettle();
    expect(find.text('Timeline 0:00.750'), findsOneWidget);
    expect(
      find.text('Observed at 0:00.050 · 0 contacts so far'),
      findsOneWidget,
    );
    await tester.tap(find.text('Play replay'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Timeline 0:01.000'), findsOneWidget);
    expect(find.text('Play replay'), findsOneWidget);
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(find.text('Timeline 0:00.050'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('old saved summary cannot pretend to have a replay', (
    tester,
  ) async {
    final repository = MemorySessions()..data = [savedSession()];
    final c = await studio(repository: repository);
    await mount(tester, ReplayScreen(studio: c, id: 'demo-test'));
    expect(find.text('No replay checkpoints'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    await mount(tester, RecordedSessionScreen(studio: c, id: 'demo-test'));
    await tester.scrollUntilVisible(
      find.text(
        'Replay unavailable: this older session saved a summary only. New recordings include replay checkpoints.',
      ),
      180,
    );
    expect(find.text('Walk Replay'), findsNothing);
  });
  testWidgets('CSV copy and share expose actual data, errors and retry', (
    tester,
  ) async {
    final delivery = FakeCsvDelivery()..fail = true;
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showCsvExport(context, [savedSession()], delivery: delivery),
            child: const Text('Export'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy CSV'));
    await tester.pumpAndSettle();
    expect(clipboard, contains('"demo-test"'));
    expect(find.text('CSV copied to clipboard.'), findsOneWidget);
    await tester.tap(find.text('Share CSV file'));
    await tester.pumpAndSettle();
    expect(
      find.text('Export could not complete. Retry or use Copy CSV.'),
      findsOneWidget,
    );
    delivery.fail = false;
    await tester.tap(find.text('Share CSV file'));
    await tester.pumpAndSettle();
    expect(delivery.received, clipboard);
    expect(
      find.text('Share sheet dismissed. No destination selected.'),
      findsOneWidget,
    );
  });
  testWidgets('history read failure hides analytics and can retry', (
    tester,
  ) async {
    final repository = MemorySessions()..failLoad = true;
    final c = await studio(repository: repository);
    await mount(tester, HistoryScreen(studio: c, progress: await prefs()));
    expect(find.text('History unavailable'), findsOneWidget);
    expect(find.byType(TrendChart), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.text('Retry history'));
    await tester.pumpAndSettle();
    expect(find.text('Your first recording starts here'), findsOneWidget);
  });
}
