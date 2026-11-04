import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride_ai/core/theme.dart';
import 'package:stride_ai/features/coach/coach_screen.dart';
import 'package:stride_ai/domain/coach/coach_models.dart';
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
    );
    addTearDown(() {
      c.dispose();
      studio.dispose();
      progress.dispose();
    });
    return c;
  }

  Future<void> mount(
    WidgetTester tester,
    CoachController c, {
    Brightness brightness = Brightness.dark,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: strideTheme(brightness),
        home: CoachScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String question) async {
    await tester.enterText(find.byType(TextField), question);
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty coach communicates missing recordings and answers without sample measurements',
    (tester) async {
      final c = await coach();
      await mount(tester, c);
      expect(
        find.text('A conversation starts with a saved walk.'),
        findsOneWidget,
      );
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Send question',
        ),
      );
      expect(button.onPressed, isNull);
      await send(tester, 'daily summary');
      expect(
        find.textContaining('Today has no saved recordings'),
        findsOneWidget,
      );
      expect(find.text('NEEDS MORE DATA'), findsOneWidget);
      expect(c.exchanges.single.response!.text, isNot(contains('6420')));
    },
  );
  testWidgets('suggested questions open explainable answers and source links', (
    tester,
  ) async {
    final records = MemorySessions()..data = [savedSession()];
    final c = await coach(records: records);
    await mount(tester, c);
    await tester.scrollUntilVisible(
      find.widgetWithText(ActionChip, 'Explain my walk').hitTestable(),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Explain my walk'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Why this answer?').hitTestable(),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Why this answer?'));
    await tester.pumpAndSettle();
    expect(find.text('Explainable movement calculations'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(ActionChip, 'Recording 1').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.widgetWithText(ActionChip, 'Recording 1'), findsOneWidget);
    expect(c.exchanges.single.response!.evidence.single.sessionIds, [
      'demo-test',
    ]);
  });
  testWidgets('pending request shows loading and blocks duplicate sends', (
    tester,
  ) async {
    final provider = DeferredCoach();
    final c = await coach(provider: provider);
    await mount(tester, c);
    await tester.enterText(find.byType(TextField), 'daily summary');
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.busy, isTrue);
    expect(
      find.text('Preparing an answer from saved data…').hitTestable(),
      findsOneWidget,
    );
    provider.complete();
    await tester.pumpAndSettle();
    expect(c.busy, isFalse);
    expect(c.exchanges.length, 1);
  });
  testWidgets(
    'failure exposes retry and retry prepares a real local response',
    (tester) async {
      final provider = FlakyCoach();
      final c = await coach(provider: provider);
      await mount(tester, c);
      await send(tester, 'daily summary');
      expect(find.text('Retry answer'), findsOneWidget);
      provider.fail = false;
      await tester.tap(find.text('Retry answer'));
      await tester.pumpAndSettle();
      expect(find.text('Retry answer'), findsNothing);
      expect(find.text('NEEDS MORE DATA'), findsOneWidget);
    },
  );
  testWidgets(
    'source changes hide stale answers and regeneration uses current data',
    (tester) async {
      final records = MemorySessions()..data = [savedSession()];
      final c = await coach(records: records);
      await mount(tester, c);
      await send(tester, 'daily summary');
      expect(
        c.exchanges.single.response!.text,
        contains('100 simulated contacts'),
      );
      records.data.add(savedSession(id: 'new', steps: 200));
      await c.studio.loadHistory();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This earlier answer is hidden'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Regenerate from current data').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Regenerate from current data'));
      await tester.pumpAndSettle();
      expect(
        c.exchanges.single.response!.text,
        contains('300 simulated contacts'),
      );
      expect(
        find.textContaining('This earlier answer is hidden'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'clear chat requires confirmation and preserves saved recordings',
    (tester) async {
      final records = MemorySessions()..data = [savedSession()];
      final c = await coach(records: records);
      await c.ask('daily summary');
      await mount(tester, c);
      await tester.tap(find.byTooltip('Clear local chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep chat'));
      await tester.pumpAndSettle();
      expect(c.exchanges.length, 1);
      await tester.tap(find.byTooltip('Clear local chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear chat'));
      await tester.pumpAndSettle();
      expect(c.exchanges, isEmpty);
      expect(c.studio.sessions.length, 1);
    },
  );
  testWidgets('light theme and compact keyboard layout remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await coach();
    await mount(tester, c, brightness: Brightness.light);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await send(tester, 'weekly summary');
    expect(tester.takeException(), isNull);
    expect(c.exchanges.single.response!.kind, CoachResponseKind.insufficient);
  });
  testWidgets(
    'history load error stays distinct from empty and retry restores ready state',
    (tester) async {
      final records = MemorySessions()..failLoad = true;
      final c = await coach(records: records);
      await mount(tester, c);
      expect(find.text('History unavailable'), findsOneWidget);
      expect(
        find.text('A conversation starts with a saved walk.'),
        findsNothing,
      );
      records.failLoad = false;
      await tester.scrollUntilVisible(
        find.text('Retry history').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Retry history'));
      await tester.pumpAndSettle();
      expect(
        find.text('A conversation starts with a saved walk.'),
        findsOneWidget,
      );
    },
  );
}
