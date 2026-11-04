import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/app_preferences.dart';
import '../domain/demo_repository.dart';
import '../domain/safety/device_preview.dart';
import 'preferences_controller.dart';
import 'studio_controller.dart';

class DeviceHubController extends ChangeNotifier {
  DeviceHubController({
    required this.studio,
    required this.preferences,
    HapticPreviewPort? haptics,
  }) : haptics = haptics ?? LocalHapticPreview();
  final StudioController studio;
  final PreferencesController preferences;
  final HapticPreviewPort haptics;
  DemoConnectionPhase phase = DemoConnectionPhase.demo;
  HapticPattern pattern = HapticPattern.gentleDouble;
  HapticPreviewReceipt? receipt;
  String message =
      'Virtual insole ready. No hardware was discovered or connected.';
  String? hapticError;
  bool hapticBusy = false, _disposed = false;
  int _generation = 0;
  Timer? _connectionTimer;
  bool get usable =>
      phase == DemoConnectionPhase.demo ||
      phase == DemoConnectionPhase.connected;
  DeviceState get legacyState => phase == DemoConnectionPhase.connected
      ? DeviceState.connected
      : phase == DemoConnectionPhase.demo
      ? DeviceState.demo
      : DeviceState.disconnected;
  void setPreview(DeviceState state) {
    _stopPending();
    phase = switch (state) {
      DeviceState.demo => DemoConnectionPhase.demo,
      DeviceState.connected => DemoConnectionPhase.connected,
      DeviceState.disconnected => DemoConnectionPhase.disconnected,
    };
    studio.setConnected(usable);
    message =
        'Static UI state preview: ${state.name}. No connection was attempted.';
    notifyListeners();
  }

  void connect({bool automatic = true}) {
    if (phase == DemoConnectionPhase.connecting || !preferences.ready) {
      return;
    }
    _stopPending();
    if (preferences.data.settings.nearbyPermission !=
        PermissionPreview.allowed) {
      phase = DemoConnectionPhase.error;
      studio.setConnected(false);
      message =
          'Connection exercise blocked by the nearby-device permission preview. Select Allowed to practice this flow. OS permission is not queried or requested.';
      notifyListeners();
      return;
    }
    phase = DemoConnectionPhase.connecting;
    studio.setConnected(false);
    message = 'Connecting to the virtual insole…';
    notifyListeners();
    if (automatic) {
      _connectionTimer = Timer(
        const Duration(milliseconds: 600),
        completeConnection,
      );
    }
  }

  void completeConnection() {
    if (phase != DemoConnectionPhase.connecting) {
      return;
    }
    _connectionTimer?.cancel();
    _connectionTimer = null;
    if (!preferences.ready ||
        preferences.data.settings.nearbyPermission !=
            PermissionPreview.allowed) {
      simulateError();
      return;
    }
    phase = DemoConnectionPhase.connected;
    studio.setConnected(true);
    message =
        'Connected · simulated. No Bluetooth radio or firmware was contacted.';
    notifyListeners();
  }

  void disconnect() => setPreview(DeviceState.disconnected);
  void simulateError() {
    _stopPending();
    phase = DemoConnectionPhase.error;
    studio.setConnected(false);
    message =
        'Simulated connection failure. Choose a demo state or retry the connection exercise.';
    notifyListeners();
  }

  void setPattern(HapticPattern value) {
    if (hapticBusy) {
      return;
    }
    pattern = value;
    receipt = null;
    hapticError = null;
    notifyListeners();
  }

  Future<void> previewHaptic() async {
    if (!usable || hapticBusy) {
      return;
    }
    final generation = ++_generation;
    hapticBusy = true;
    receipt = null;
    hapticError = null;
    notifyListeners();
    try {
      final result = await haptics
          .preview(pattern)
          .timeout(const Duration(seconds: 5));
      if (_disposed || generation != _generation || !usable) {
        return;
      }
      receipt = result;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        hapticError =
            'Command preview failed. Retry; no vibration or radio command was sent.';
      }
    }
    if (_disposed || generation != _generation) {
      return;
    }
    hapticBusy = false;
    notifyListeners();
  }

  void _stopPending() {
    _generation++;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    hapticBusy = false;
    receipt = null;
    hapticError = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPending();
    super.dispose();
  }
}
