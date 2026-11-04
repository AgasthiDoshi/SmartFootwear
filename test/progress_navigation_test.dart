import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/domain/session_repository.dart';
import 'package:stride_ai/services/progress_controller.dart';
import 'package:stride_ai/services/studio_controller.dart';

void main() {
  testWidgets(
    'persisted recording routes through history, details, replay, export and deletion',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      final producer = StudioController(clock: () => DateTime(2026, 10, 21, 9));
      await producer.loadHistory();
      producer.startSession(automatic: false);
      for (var i = 0; i < 120; i++) {
        producer.tick();
      }
      await producer.stop();
      producer.dispose();
      final app = AppController(
        progress: ProgressController(clock: () => DateTime(2026, 10, 21, 12)),
      );
      await app.restore();
      await tester.pumpWidget(StrideApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Progress & history').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Progress & history'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('10 steps · 6.0 s').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('10 steps · 6.0 s'));
      await tester.pumpAndSettle();
      expect(find.text('10 steps'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Walk Replay').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Walk Replay'));
      await tester.pumpAndSettle();
      expect(find.text('Walk Replay'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(3000);
      await tester.pumpAndSettle();
      expect(find.text('Timeline 0:03.000'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Export all saved recordings as CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Export CSV'), findsOneWidget);
      expect(
        find.textContaining('1 saved simulated session(s).'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('10 steps · 6.0 s').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('10 steps · 6.0 s'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete recording').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Your first recording starts here'), findsOneWidget);
      expect(await LocalSessionRepository().load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
