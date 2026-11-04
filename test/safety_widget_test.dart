import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/core/theme.dart';
import 'package:stride_ai/domain/app_preferences.dart';
import 'package:stride_ai/domain/safety/safety_models.dart';
import 'package:stride_ai/features/safety/safety_screen.dart';
import 'package:stride_ai/features/safety/contacts_screen.dart';
import 'package:stride_ai/features/devices/device_hub_screen.dart';
import 'package:stride_ai/features/settings/notifications_screen.dart';
import 'package:stride_ai/features/settings/privacy_screen.dart';
import 'package:stride_ai/services/preferences_controller.dart';
import 'package:stride_ai/services/safety_controller.dart';
import 'helpers/safety_fixtures.dart';

void main() {
  Future<PreferencesController> prefs({
    bool contacts = true,
    MemoryAppPreferences? repository,
  }) async {
    final p = PreferencesController(
      repository:
          repository ??
          (MemoryAppPreferences()
            ..data = AppPreferences(contacts: contacts ? [testContact] : [])),
    );
    addTearDown(p.dispose);
    await p.load();
    return p;
  }

  SafetyController safety(
    PreferencesController p, {
    SpyEmergencyPreview? port,
  }) {
    final s = SafetyController(preferences: p, previewPort: port);
    addTearDown(s.dispose);
    return s;
  }

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(theme: strideTheme(Brightness.dark), home: child),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    double delta = 150,
  }) async {
    await tester.scrollUntilVisible(
      finder.hitTestable(),
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<AppController> app({MemoryAppPreferences? repository}) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final c = AppController(
      preferences: PreferencesController(
        repository: repository ?? MemoryAppPreferences(),
      ),
    );
    await c.restore();
    return c;
  }

  testWidgets(
    'fall practice exposes countdown and cancellation before any preview',
    (tester) async {
      final p = await prefs();
      final port = SpyEmergencyPreview();
      final s = safety(p, port: port);
      await mount(tester, SafetyScreen(safety: s, preferences: p));
      await reveal(tester, find.text('Fall event'));
      await tester.tap(find.text('Fall event'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Simulate fall event'));
      await tester.tap(find.text('Simulate fall event'));
      await tester.pump();
      expect(s.phase, SafetyPhase.countdown);
      await reveal(tester, find.text('Cancel alert · I’m okay'));
      await tester.tap(find.text('Cancel alert · I’m okay'));
      await tester.pumpAndSettle();
      expect(s.phase, SafetyPhase.cancelled);
      expect(port.requests, isEmpty);
      expect(
        find.text('Practice cancelled. Nothing was sent.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'test alert finishes with a simulated receipt and no contacts blocks safely',
    (tester) async {
      final p = await prefs();
      final port = SpyEmergencyPreview();
      final s = safety(p, port: port);
      await mount(tester, SafetyScreen(safety: s, preferences: p));
      await reveal(tester, find.text('Start test alert'));
      await tester.tap(find.text('Start test alert'));
      await tester.pumpAndSettle();
      expect(s.phase, SafetyPhase.completed);
      expect(port.requests.length, 1);
      await p.clearContacts();
      await tester.tap(find.text('Start test alert'));
      await tester.pumpAndSettle();
      expect(s.phase, SafetyPhase.blocked);
      expect(port.requests.length, 1);
    },
  );
  testWidgets(
    'manual contacts support validation, masked display, edit and removal',
    (tester) async {
      final p = await prefs(contacts: false);
      await mount(tester, ContactsScreen(preferences: p));
      await reveal(tester, find.text('Add contact'));
      await tester.tap(find.text('Add contact'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a name from 1 to 60 characters.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact name'),
        'Demo Friend',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        '+91 98765 43210',
      );
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      expect(p.data.contacts.length, 1);
      await reveal(tester, find.text('••• 210'), delta: -100);
      expect(find.text('+91 98765 43210'), findsNothing);
      await tester.tap(find.byTooltip('Edit Demo Friend'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact name'),
        'Updated Friend',
      );
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byTooltip('Remove Updated Friend'),
        delta: -100,
      );
      await tester.tap(find.byTooltip('Remove Updated Friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove contact'));
      await tester.pumpAndSettle();
      expect(p.data.contacts, isEmpty);
    },
  );
  testWidgets(
    'failed contact save retains the editor and previously saved contacts',
    (tester) async {
      final repository = MemoryAppPreferences();
      final p = await prefs(repository: repository);
      await mount(tester, ContactsScreen(preferences: p));
      await reveal(tester, find.text('Add contact'));
      await tester.tap(find.text('Add contact'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact name'),
        'Friend',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        '1234567890',
      );
      repository.failSave = true;
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      expect(p.data.contacts, isEmpty);
      expect(find.text('Add emergency contact'), findsOneWidget);
      expect(find.textContaining('Could not save.'), findsWidgets);
      repository.failSave = false;
      await tester.tap(find.text('Save contact'));
      await tester.pumpAndSettle();
      expect(p.data.contacts.length, 1);
    },
  );
  testWidgets(
    'notification previews honor denied/allowed states and disabled notices',
    (tester) async {
      final p = await prefs();
      final s = safety(p);
      await mount(tester, NotificationsScreen(preferences: p, safety: s));
      await reveal(tester, find.text('Preview safety notice'));
      await tester.tap(find.text('Preview safety notice'));
      await tester.pumpAndSettle();
      expect(s.notificationPreview, contains('suppressed'));
      final dropdown = tester.widget<DropdownButton<PermissionPreview>>(
        find.byType(DropdownButton<PermissionPreview>),
      );
      dropdown.onChanged!(PermissionPreview.allowed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview safety notice'));
      await tester.pumpAndSettle();
      expect(s.notificationPreview, contains('DEMO in-app notice only'));
      await reveal(tester, find.text('Safety preview notices'), delta: -120);
      await tester.tap(find.text('Safety preview notices'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Preview safety notice'));
      await tester.tap(find.text('Preview safety notice'));
      await tester.pumpAndSettle();
      expect(s.notificationPreview, contains('disabled'));
    },
  );
  testWidgets(
    'failed permission preference write does not display an unsaved grant',
    (tester) async {
      final store = MemoryAppPreferences();
      final p = await prefs(repository: store);
      final s = safety(p);
      await mount(tester, NotificationsScreen(preferences: p, safety: s));
      store.failSave = true;
      final dropdown = tester.widget<DropdownButton<PermissionPreview>>(
        find.byType(DropdownButton<PermissionPreview>),
      );
      dropdown.onChanged!(PermissionPreview.allowed);
      await tester.pumpAndSettle();
      expect(
        p.data.settings.notificationPermission,
        PermissionPreview.notRequested,
      );
      expect(
        tester
            .widget<DropdownButton<PermissionPreview>>(
              find.byType(DropdownButton<PermissionPreview>),
            )
            .value,
        PermissionPreview.notRequested,
      );
    },
  );
  testWidgets(
    'device states disable disconnected commands and preview haptics locally',
    (tester) async {
      final c = await app();
      addTearDown(c.dispose);
      await mount(tester, DeviceHubScreen(app: c));
      await reveal(tester, find.text('disconnected'));
      await tester.tap(find.text('disconnected'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Preview haptic command'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Preview haptic command'),
      );
      expect(button.onPressed, isNull);
      await reveal(tester, find.text('Connected (simulated)'), delta: -200);
      await tester.tap(find.text('Connected (simulated)'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Preview haptic command'));
      await tester.tap(find.text('Preview haptic command'));
      await tester.pumpAndSettle();
      expect(c.devices.receipt!.command['mode'], 'preview_only');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'privacy replay setting controls new recordings without deleting summaries',
    (tester) async {
      final c = await app();
      addTearDown(c.dispose);
      await mount(tester, PrivacyScreen(app: c));
      await reveal(tester, find.text('Save replay checkpoints'));
      await tester.tap(find.text('Save replay checkpoints'));
      await tester.pumpAndSettle();
      expect(c.studio.retainReplay, isFalse);
      c.studio.startSession(automatic: false);
      for (var i = 0; i < 120; i++) {
        c.studio.tick();
      }
      await c.studio.stop();
      await tester.pumpAndSettle();
      expect(c.studio.sessions.single.replay, isEmpty);
      expect(c.studio.sessions.single.steps, 10);
    },
  );
  testWidgets(
    'global cancellation works across tabs and backgrounding cancels an active practice',
    (tester) async {
      final c = await app(
        repository: MemoryAppPreferences()
          ..data = AppPreferences(contacts: [testContact]),
      );
      await tester.pumpWidget(StrideApp(controller: c));
      await tester.pumpAndSettle();
      c.safety.startFall();
      await tester.pump();
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(c.safety.phase, SafetyPhase.cancelled);
      c.safety.startFall();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(c.safety.phase, SafetyPhase.cancelled);
      expect(c.safety.receipt, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  );
  testWidgets('compact safety layout supports readable permission states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = await prefs(contacts: false);
    final s = safety(p);
    await mount(tester, SafetyScreen(safety: s, preferences: p));
    await reveal(tester, find.text('Start test alert'));
    await tester.tap(find.text('Start test alert'));
    await tester.pumpAndSettle();
    expect(s.phase, SafetyPhase.blocked);
    expect(tester.takeException(), isNull);
  });
}
