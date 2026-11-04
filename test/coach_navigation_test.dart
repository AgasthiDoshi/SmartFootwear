import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/domain/session_repository.dart';
import 'package:stride_ai/services/progress_controller.dart';
import 'helpers/progress_fixtures.dart';

void main() {
  testWidgets(
    'coach keyboard send and evidence link use persisted session data',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      await LocalSessionRepository().save([savedSession()]);
      final c = AppController(
        progress: ProgressController(clock: () => DateTime(2026, 10, 21, 12)),
      );
      await c.restore();
      await tester.pumpWidget(StrideApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Explain my latest recording.',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(
        c.coach.exchanges.single.response!.text,
        contains('100 simulated contacts'),
      );
      await tester.scrollUntilVisible(
        find.text('Why this answer?').hitTestable(),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Why this answer?'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ActionChip, 'Recording 1').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Recording 1'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded walk'), findsOneWidget);
      expect(find.text('100 steps'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(c.coach.exchanges.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
