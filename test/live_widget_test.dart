import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride_ai/core/theme.dart';
import 'package:stride_ai/features/live/live_screen.dart';
import 'package:stride_ai/features/live/insole_view.dart';
import 'package:stride_ai/features/live/sensor_chart.dart';
import 'package:stride_ai/features/gait/gait_screen.dart';
import 'package:stride_ai/features/history/history_screen.dart';
import 'package:stride_ai/services/studio_controller.dart';
import 'package:stride_ai/services/progress_controller.dart';
import 'sensor_processing_test.dart' show MemorySessions;

void main() {
  Future<void> showLive(WidgetTester tester, StudioController c) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: strideTheme(Brightness.dark),
        home: Scaffold(body: LiveScreen(studio: c)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('recording controls transition through pause resume and save', (
    tester,
  ) async {
    final c = StudioController(repository: MemorySessions());
    addTearDown(c.dispose);
    await c.loadHistory();
    await showLive(tester, c);
    await reveal(tester, 'Start session');
    await tester.tap(find.text('Start session'));
    await tester.pump(const Duration(seconds: 3));
    expect(c.detector.steps, greaterThan(0));
    await reveal(tester, 'Pause session');
    await tester.tap(find.text('Pause session'));
    await tester.pump();
    final time = c.activeMilliseconds;
    await tester.pump(const Duration(seconds: 1));
    expect(c.activeMilliseconds, time);
    await tester.tap(find.text('Resume session'));
    await tester.pump(const Duration(seconds: 1));
    expect(c.phase, SessionPhase.recording);
    await tester.tap(find.text('Stop & save'));
    await tester.pumpAndSettle();
    expect(c.sessions.length, 1);
    expect(find.text('View saved session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'disconnected state disables start and calibration shows progress',
    (tester) async {
      final c = StudioController(repository: MemorySessions());
      addTearDown(c.dispose);
      await c.loadHistory();
      c.setConnected(false);
      await showLive(tester, c);
      await reveal(tester, 'Start session');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start session'),
            )
            .onPressed,
        isNull,
      );
      c.setConnected(true);
      await tester.pumpAndSettle();
      await reveal(tester, 'Calibrate sensors');
      await tester.tap(find.text('Calibrate sensors'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.calibrating, isTrue);
      expect(find.text('Cancel calibration'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(c.calibrated, isTrue);
      c.stopFeed();
      await tester.pumpAndSettle();
      expect(
        find.text('Calibrated · FSR zeroed, gravity retained at 1 g'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reset baseline'));
      await tester.pumpAndSettle();
      expect(c.calibrated, isFalse);
    },
  );
  testWidgets('save error is visible and retry saves the retained recording', (
    tester,
  ) async {
    final repository = MemorySessions()..failSave = true;
    final c = StudioController(repository: repository);
    addTearDown(c.dispose);
    await c.loadHistory();
    c.startSession(automatic: false);
    for (var i = 0; i < 30; i++) {
      c.tick();
    }
    await c.stop();
    await showLive(tester, c);
    await reveal(tester, 'Retry save');
    expect(c.phase, SessionPhase.unsaved);
    repository.failSave = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(c.sessions.length, 1);
    expect(find.text('Retry save'), findsNothing);
  });
  testWidgets('compact insole, all nine charts and gait insights lay out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = StudioController(repository: MemorySessions());
    addTearDown(c.dispose);
    await c.loadHistory();
    c.startSession(automatic: false);
    for (var i = 0; i < 120; i++) {
      c.tick();
    }
    c.pause();
    c.stopFeed();
    await showLive(tester, c);
    await tester.scrollUntilVisible(find.byType(InsoleView), 180);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (widget) => widget is SensorChart && widget.channel == 8,
      ),
      180,
    );
    await tester.pumpAndSettle();
    expect(find.byType(SensorChart), findsNWidgets(9));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: strideTheme(Brightness.light),
        home: GaitScreen(studio: c),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10 detected contacts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history has empty, saved and deleted states', (tester) async {
    final progress = ProgressController();
    addTearDown(progress.dispose);
    final c = StudioController(repository: MemorySessions());
    addTearDown(c.dispose);
    await c.loadHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(studio: c, progress: progress),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your first recording starts here'), findsOneWidget);
    c.startSession(automatic: false);
    c.tick();
    await c.stop();
    await tester.pumpAndSettle();
    expect(find.text('Your first recording starts here'), findsNothing);
    await c.deleteSession(c.sessions.single.id);
    await tester.pumpAndSettle();
    expect(find.text('Your first recording starts here'), findsOneWidget);
  });
}
