import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/domain/app_preferences.dart';
import 'package:stride_ai/domain/app_preferences_repository.dart';
import 'package:stride_ai/domain/safety/safety_models.dart';
import 'package:stride_ai/domain/safety/device_preview.dart';
import 'package:stride_ai/domain/demo_repository.dart';
import 'package:stride_ai/services/preferences_controller.dart';
import 'package:stride_ai/services/safety_controller.dart';
import 'package:stride_ai/services/studio_controller.dart';
import 'package:stride_ai/services/device_hub_controller.dart';
import 'helpers/safety_fixtures.dart';
import 'sensor_processing_test.dart' show MemorySessions;

void main() {
  Future<PreferencesController> preferences({
    MemoryAppPreferences? repository,
    bool contacts = true,
    AppSettings settings = const AppSettings(),
  }) async {
    final store =
        repository ??
        (MemoryAppPreferences()
          ..data = AppPreferences(
            contacts: contacts ? [testContact] : [],
            settings: settings,
          ));
    final p = PreferencesController(
      repository: store,
      clock: () => DateTime(2026, 10, 21, 12),
    );
    addTearDown(p.dispose);
    await p.load();
    return p;
  }

  Future<SafetyController> safety({
    bool contacts = true,
    SpyEmergencyPreview? port,
    AppSettings settings = const AppSettings(),
  }) async {
    final p = await preferences(contacts: contacts, settings: settings);
    final s = SafetyController(preferences: p, previewPort: port);
    addTearDown(s.dispose);
    return s;
  }

  test(
    'fall countdown transitions exactly once to a simulation-only receipt',
    () async {
      final port = SpyEmergencyPreview();
      final s = await safety(
        port: port,
        settings: const AppSettings(countdownSeconds: 5),
      );
      s.startFall(automatic: false);
      expect(s.phase, SafetyPhase.countdown);
      expect(s.remainingSeconds, 5);
      for (var i = 0; i < 4; i++) {
        await s.tick();
      }
      expect(s.remainingSeconds, 1);
      expect(port.requests, isEmpty);
      await s.tick();
      await s.tick();
      expect(s.phase, SafetyPhase.completed);
      expect(port.requests.length, 1);
      expect(s.receipt!.recipientCount, 1);
      expect(
        s.message,
        contains('No message, call or emergency request was sent'),
      );
    },
  );
  test('cancel prevents countdown expiry from invoking any preview', () async {
    final port = SpyEmergencyPreview();
    final s = await safety(port: port);
    s.startFall(automatic: false);
    await s.tick();
    s.cancel();
    for (var i = 0; i < 20; i++) {
      await s.tick();
    }
    expect(s.phase, SafetyPhase.cancelled);
    expect(port.requests, isEmpty);
    expect(s.receipt, isNull);
    s.reset();
    expect(s.phase, SafetyPhase.idle);
  });
  test('cancelling in-flight preview ignores a late completion', () async {
    final port = SpyEmergencyPreview()
      ..deferred = Completer<EmergencyPreviewReceipt>();
    final s = await safety(port: port);
    final pending = s.startTest();
    expect(s.phase, SafetyPhase.previewing);
    s.cancel();
    port.deferred!.complete(const EmergencyPreviewReceipt(1));
    await pending;
    expect(s.phase, SafetyPhase.cancelled);
    expect(s.receipt, isNull);
    expect(s.events.any((e) => e.phase == SafetyPhase.completed), isFalse);
  });
  test(
    'empty or excluded contacts block the preview without a delivery call',
    () async {
      final port = SpyEmergencyPreview();
      final s = await safety(contacts: false, port: port);
      await s.startTest();
      expect(s.phase, SafetyPhase.blocked);
      expect(port.requests, isEmpty);
      await s.preferences.saveContact(
        name: 'Excluded',
        phone: '1234567890',
        included: false,
      );
      await s.startTest();
      expect(s.phase, SafetyPhase.blocked);
      expect(port.requests, isEmpty);
    },
  );
  test(
    'test mode creates an immediate local preview and blocks overlapping starts',
    () async {
      final port = SpyEmergencyPreview()
        ..deferred = Completer<EmergencyPreviewReceipt>();
      final s = await safety(port: port);
      final pending = s.startTest();
      s.startFall(automatic: false);
      expect(s.phase, SafetyPhase.previewing);
      expect(port.requests.length, 1);
      expect(port.requests.single.kind, SafetyEventKind.testAlert);
      port.deferred!.complete(const EmergencyPreviewReceipt(1));
      await pending;
      expect(s.phase, SafetyPhase.completed);
      s.cancel();
      expect(s.phase, SafetyPhase.completed);
    },
  );
  test(
    'recipient counts and countdown duration are frozen at event start',
    () async {
      final port = SpyEmergencyPreview();
      final s = await safety(
        port: port,
        settings: const AppSettings(countdownSeconds: 5),
      );
      s.startFall(automatic: false);
      await s.preferences.clearContacts();
      await s.preferences.setSettings(const AppSettings(countdownSeconds: 20));
      for (var i = 0; i < 5; i++) {
        await s.tick();
      }
      expect(s.phase, SafetyPhase.completed);
      expect(port.requests.single.recipientCount, 1);
      expect(s.initialSeconds, 5);
      await s.startTest();
      expect(s.phase, SafetyPhase.blocked);
      expect(port.requests.length, 1);
    },
  );
  test(
    'failed local preview can be retried and practice log is bounded',
    () async {
      final port = SpyEmergencyPreview()..fail = true;
      final s = await safety(port: port);
      await s.startTest();
      expect(s.phase, SafetyPhase.error);
      expect(s.receipt, isNull);
      port.fail = false;
      for (var i = 0; i < 30; i++) {
        await s.startTest();
      }
      expect(s.phase, SafetyPhase.completed);
      expect(s.events.length, 20);
      expect(() => s.events.clear(), throwsUnsupportedError);
    },
  );
  test(
    'unreadable preferences block safety rather than inventing contacts',
    () async {
      final store = MemoryAppPreferences()..failLoad = true;
      final p = await preferences(repository: store);
      final port = SpyEmergencyPreview();
      final s = SafetyController(preferences: p, previewPort: port);
      addTearDown(s.dispose);
      await s.startTest();
      s.startFall(automatic: false);
      expect(s.phase, SafetyPhase.idle);
      expect(port.requests, isEmpty);
      store.failLoad = false;
      await p.load();
      expect(s.canStart, isTrue);
    },
  );
  test(
    'notification previews honor preferences and all preview permission states',
    () async {
      final s = await safety();
      for (final permission in [
        PermissionPreview.notRequested,
        PermissionPreview.denied,
        PermissionPreview.restricted,
      ]) {
        await s.preferences.setSettings(
          AppSettings(notificationPermission: permission),
        );
        s.previewNotification();
        expect(s.notificationPreview, contains('suppressed'));
      }
      await s.preferences.setSettings(
        const AppSettings(notificationPermission: PermissionPreview.allowed),
      );
      s.previewNotification();
      expect(s.notificationPreview, contains('DEMO in-app notice only'));
      await s.preferences.setSettings(
        const AppSettings(
          notificationPermission: PermissionPreview.allowed,
          safetyNotices: false,
        ),
      );
      s.previewNotification();
      expect(s.notificationPreview, contains('disabled'));
      s.previewNotification(reminder: true);
      expect(s.notificationPreview, contains('disabled'));
    },
  );
  test(
    'contacts validate, reject duplicate numbers and preserve IDs during edit',
    () async {
      final p = await preferences(contacts: false);
      expect(await p.saveContact(name: '', phone: '1'), isFalse);
      expect(
        await p.saveContact(name: 'Friend', phone: '+91 98765 43210'),
        isTrue,
      );
      final id = p.data.contacts.single.id;
      expect(
        await p.saveContact(name: 'Duplicate', phone: '+919876543210'),
        isFalse,
      );
      expect(
        await p.saveContact(
          id: id,
          name: 'Edited',
          phone: '+91 98765 43210',
          included: false,
        ),
        isTrue,
      );
      expect(p.data.contacts.single.id, id);
      expect(p.data.contacts.single.included, isFalse);
      expect(p.data.contacts.single.maskedPhone, '••• 210');
    },
  );
  test('contact limit and constant clock still produce unique IDs', () async {
    final p = await preferences(contacts: false);
    for (var i = 0; i < 5; i++) {
      expect(
        await p.saveContact(name: 'Person $i', phone: '123456789$i'),
        isTrue,
      );
    }
    expect(p.data.contacts.map((c) => c.id).toSet().length, 5);
    expect(await p.saveContact(name: 'Six', phone: '9999999999'), isFalse);
  });
  test(
    'contact/settings write failures preserve saved values and can retry',
    () async {
      final store = MemoryAppPreferences()
        ..data = AppPreferences(contacts: [testContact]);
      final p = await preferences(repository: store);
      store.failSave = true;
      expect(await p.deleteContact(testContact.id), isFalse);
      expect(p.data.contacts.length, 1);
      expect(
        await p.setSettings(const AppSettings(maskPhones: false)),
        isFalse,
      );
      expect(p.data.settings.maskPhones, isTrue);
      store.failSave = false;
      expect(await p.deleteContact(testContact.id), isTrue);
      expect(p.data.contacts, isEmpty);
    },
  );
  test(
    'profile, contacts, permissions and preferences survive recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = PreferencesController();
      addTearDown(p.dispose);
      await p.load();
      await p.setProfile('Sam');
      await p.saveContact(name: 'Friend', phone: '+91 98765 43210');
      await p.setSettings(
        const AppSettings(
          countdownSeconds: 20,
          testAlertMode: false,
          maskPhones: false,
          retainReplay: false,
          reduceMotion: true,
          notificationPermission: PermissionPreview.denied,
        ),
      );
      final restored = PreferencesController();
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.data.toJson(), p.data.toJson());
      expect(restored.data.profile.displayName, 'Sam');
      await restored.resetSettings();
      expect(restored.data.contacts.length, 1);
      expect(restored.data.profile.displayName, 'Sam');
      expect(restored.data.settings.countdownSeconds, 10);
    },
  );
  test(
    'corrupt preference storage cannot be overwritten by form actions',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalAppPreferencesRepository.key: '{broken',
      });
      final p = PreferencesController();
      addTearDown(p.dispose);
      await p.load();
      expect(p.ready, isFalse);
      expect(await p.saveContact(name: 'Friend', phone: '1234567890'), isFalse);
      expect(await p.setSettings(const AppSettings()), isFalse);
    },
  );
  test(
    'connection exercise honors preview permissions and cancellation',
    () async {
      final p = await preferences();
      final studio = StudioController(repository: MemorySessions());
      addTearDown(studio.dispose);
      final device = DeviceHubController(studio: studio, preferences: p);
      addTearDown(device.dispose);
      device.connect(automatic: false);
      expect(device.phase, DemoConnectionPhase.error);
      expect(studio.connected, isFalse);
      await p.setSettings(
        const AppSettings(nearbyPermission: PermissionPreview.allowed),
      );
      device.connect(automatic: false);
      expect(device.phase, DemoConnectionPhase.connecting);
      device.disconnect();
      device.completeConnection();
      expect(device.phase, DemoConnectionPhase.disconnected);
      device.connect(automatic: false);
      device.completeConnection();
      expect(device.phase, DemoConnectionPhase.connected);
      expect(studio.connected, isTrue);
      device.simulateError();
      expect(device.phase, DemoConnectionPhase.error);
      expect(studio.connected, isFalse);
    },
  );
  test(
    'haptic preview never targets hardware and discards completion after disconnect',
    () async {
      final p = await preferences();
      final studio = StudioController(repository: MemorySessions());
      addTearDown(studio.dispose);
      final port = SpyHaptics();
      final device = DeviceHubController(
        studio: studio,
        preferences: p,
        haptics: port,
      );
      addTearDown(device.dispose);
      device.setPattern(HapticPattern.attentionTriple);
      await device.previewHaptic();
      expect(device.receipt!.command['mode'], 'preview_only');
      expect(device.receipt!.command['pulses'], 3);
      device.disconnect();
      await device.previewHaptic();
      expect(port.requests.length, 1);
      device.setPreview(DeviceState.demo);
      port.deferred = Completer<HapticPreviewReceipt>();
      final pending = device.previewHaptic();
      device.disconnect();
      port.deferred!.complete(
        HapticPreviewReceipt(HapticPattern.gentleDouble.command),
      );
      await pending;
      expect(device.receipt, isNull);
      expect(device.hapticBusy, isFalse);
    },
  );
  test(
    'replay retention is captured at session start and leaves summaries intact',
    () async {
      final studio = StudioController(repository: MemorySessions());
      addTearDown(studio.dispose);
      await studio.loadHistory();
      studio.retainReplay = false;
      studio.startSession(automatic: false);
      for (var i = 0; i < 120; i++) {
        studio.tick();
      }
      studio.retainReplay = true;
      await studio.stop();
      expect(studio.sessions.first.replay, isEmpty);
      expect(studio.sessions.first.steps, 10);
      studio.startSession(automatic: false);
      studio.tick();
      await studio.stop();
      expect(studio.sessions.first.replay, isNotEmpty);
    },
  );
  test('no preference can enable real emergency or hardware capabilities', () {
    final json = const AppSettings().toJson()..['realEmergencyDelivery'] = true;
    AppSettings.fromJson(json);
    expect(IntegrationCapabilities.realEmergencyDelivery, isFalse);
    expect(IntegrationCapabilities.automaticFallDetection, isFalse);
    expect(IntegrationCapabilities.bluetooth, isFalse);
    expect(IntegrationCapabilities.hardwareHaptics, isFalse);
    expect(IntegrationCapabilities.osNotifications, isFalse);
  });
}
