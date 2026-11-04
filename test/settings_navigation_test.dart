import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/domain/app_preferences.dart';
import 'package:stride_ai/domain/app_preferences_repository.dart';

void main() {
  testWidgets(
    'profile and settings navigation save preferences without changing contacts',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      final c = AppController();
      await c.restore();
      await tester.pumpWidget(StrideApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit display name'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Sam',
      );
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Sam'), findsOneWidget);
      expect(
        (await LocalAppPreferencesRepository().load()).profile.displayName,
        'Sam',
      );
      await tester.scrollUntilVisible(
        find.text('App settings').hitTestable(),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('App settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Reduce motion').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Reduce motion'));
      await tester.pumpAndSettle();
      expect(c.preferences.data.settings.reduceMotion, isTrue);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.text('Reduce motion')),
        ),
        isTrue,
      );
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      dropdown.onChanged!(20);
      await tester.pumpAndSettle();
      expect(
        (await LocalAppPreferencesRepository().load())
            .settings
            .countdownSeconds,
        20,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Privacy').hitTestable(),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mask contact phone numbers').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mask contact phone numbers'));
      await tester.pumpAndSettle();
      expect(
        (await LocalAppPreferencesRepository().load()).settings.maskPhones,
        isFalse,
      );
      expect(c.preferences.data.contacts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'unreadable private preferences disable new replay capture and safety practice',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalAppPreferencesRepository.key: 'broken',
      });
      final c = AppController();
      addTearDown(c.dispose);
      await c.restore();
      expect(c.preferences.ready, isFalse);
      expect(c.studio.retainReplay, isFalse);
      expect(c.safety.canStart, isFalse);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(LocalAppPreferencesRepository.key);
      await c.preferences.load();
      expect(
        c.preferences.data.settings.notificationPermission,
        PermissionPreview.notRequested,
      );
      expect(c.studio.retainReplay, isTrue);
    },
  );
}
