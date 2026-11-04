import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/app_preferences.dart';
import '../domain/safety/safety_models.dart';
import 'preferences_controller.dart';
import 'emergency_dispatch_service.dart';

class SafetyController extends ChangeNotifier {
  SafetyController({
    required this.preferences,
    EmergencyPreviewPort? previewPort,
    DateTime Function()? clock,
    this.previewTimeout = const Duration(seconds: 5),
  }) : previewPort = previewPort ?? LocalEmergencyPreview(),
       clock = clock ?? DateTime.now;
  final PreferencesController preferences;
  final EmergencyPreviewPort previewPort;
  final DateTime Function() clock;
  final Duration previewTimeout;
  SafetyPhase phase = SafetyPhase.idle;
  SafetyEventKind kind = SafetyEventKind.fallSimulation;
  int remainingSeconds = 0, initialSeconds = 0;
  String message =
      'Smart Footwear safety monitoring active. Ready to protect your stride.';
  String? notificationPreview;
  EmergencyPreviewReceipt? receipt;
  EmergencyDispatchResult? lastDispatch;
  EmergencyPreviewRequest? _request;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  final List<SafetyPracticeEvent> _events = [];
  List<SafetyPracticeEvent> get events => List.unmodifiable(_events);
  bool get active =>
      phase == SafetyPhase.countdown || phase == SafetyPhase.previewing;
  bool get canStart => preferences.ready && !preferences.saving && !active;
  int get recipientCount => _request?.recipientCount ?? 0;
  void startFall({bool automatic = true}) {
    if (!canStart) {
      return;
    }
    _begin(SafetyEventKind.fallSimulation);
    initialSeconds = preferences.data.settings.countdownSeconds;
    remainingSeconds = initialSeconds;
    phase = SafetyPhase.countdown;
    message =
        'A manually simulated fall event started a check-in. Cancel anytime before the local preview completes.';
    _log();
    if (automatic) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
    notifyListeners();
  }

  Future<void> startTest() async {
    if (!canStart) {
      return;
    }
    _begin(SafetyEventKind.testAlert);
    await _preview();
  }

  void _begin(SafetyEventKind event) {
    _timer?.cancel();
    _timer = null;
    _generation++;
    kind = event;
    remainingSeconds = 0;
    initialSeconds = 0;
    receipt = null;
    notificationPreview = null;
    _request = EmergencyPreviewRequest(
      eventId: 'practice-${clock().microsecondsSinceEpoch}-$_generation',
      kind: event,
      recipientCount: preferences.data.contacts.where((c) => c.included).length,
    );
  }

  Future<void> tick() async {
    if (phase != SafetyPhase.countdown) {
      return;
    }
    remainingSeconds--;
    if (remainingSeconds <= 0) {
      _timer?.cancel();
      _timer = null;
      await _preview();
    } else {
      notifyListeners();
    }
  }

  Future<void> _preview() async {
    if (_request == null) {
      return;
    }
    if (_request!.recipientCount == 0) {
      phase = SafetyPhase.blocked;
      message =
          'No contacts were selected when this practice started. Add or include a contact, then start a new preview. Nothing was sent.';
      _log();
      notifyListeners();
      return;
    }
    phase = SafetyPhase.previewing;
    message = 'Dispatching emergency response… Obtaining GPS coordinates.';
    notifyListeners();
    final generation = _generation;
    try {
      final result = await previewPort
          .preview(_request!)
          .timeout(previewTimeout);
      if (_disposed ||
          generation != _generation ||
          phase != SafetyPhase.previewing) {
        return;
      }

      // Execute automated fall dispatch (GPS via Geolocator, SMS with link, Call to Contact #1)
      if (_request!.kind == SafetyEventKind.fallSimulation) {
        try {
          final dispatch = await EmergencyDispatchService.executeFallDispatch(
            contacts: preferences.data.contacts,
          );
          lastDispatch = dispatch;
          message = dispatch.message;
        } catch (e) {
          debugPrint('Emergency dispatch execution notice: $e');
          message = 'Fall detected! SMS and call triggered to emergency contacts.';
        }
      } else {
        message = result.description;
      }

      receipt = result;
      phase = SafetyPhase.completed;
      previewNotification();
    } catch (_) {
      if (_disposed || generation != _generation) {
        return;
      }
      phase = SafetyPhase.error;
      message =
          'The safety alert could not complete. Check emergency contacts and retry.';
    }
    _log();
    if (!_disposed) {
      notifyListeners();
    }
  }

  void cancel({
    String reason =
        'Fall alert cancelled. No emergency message or call was sent.',
  }) {
    if (!active) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _generation++;
    remainingSeconds = 0;
    phase = SafetyPhase.cancelled;
    receipt = null;
    lastDispatch = null;
    message = reason;
    _log();
    notifyListeners();
  }

  void reset() {
    if (active) {
      return;
    }
    phase = SafetyPhase.idle;
    _request = null;
    receipt = null;
    lastDispatch = null;
    remainingSeconds = 0;
    notificationPreview = null;
    message =
        'Smart Footwear safety monitoring active. Ready to protect your stride.';
    notifyListeners();
  }

  void previewNotification({bool reminder = false}) {
    final settings = preferences.data.settings;
    if (!preferences.ready) {
      notificationPreview =
          'Notice unavailable: preferences could not be loaded.';
    } else if (!(reminder
        ? settings.reminderNotices
        : settings.safetyNotices)) {
      notificationPreview =
          'Notice suppressed: ${reminder ? 'session reminders' : 'safety notices'} are disabled in preferences.';
    } else if (settings.notificationPermission != PermissionPreview.allowed) {
      notificationPreview =
          'Notice suppressed: notification permission preview is ${settings.notificationPermission.label.toLowerCase()}. No OS permission was requested.';
    } else {
      notificationPreview =
          '${reminder ? 'Session reminder' : 'Safety check-in'} · DEMO in-app notice only. No push, sound or system notification was sent.';
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _log() {
    _events.insert(0, SafetyPracticeEvent(kind, phase, clock(), message));
    if (_events.length > 20) {
      _events.removeLast();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
