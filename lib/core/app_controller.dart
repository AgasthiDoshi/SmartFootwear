import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/demo_repository.dart';
import '../services/studio_controller.dart';
import '../services/progress_controller.dart';
import '../services/coach_controller.dart';
import '../domain/coach/coach_models.dart';
import '../services/preferences_controller.dart';
import '../services/safety_controller.dart';
import '../services/device_hub_controller.dart';
import '../services/admin_readings_controller.dart';

import '../services/smart_footwear_haptic_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    MovementRepository? repository,
    StudioController? studio,
    ProgressController? progress,
    CoachProvider? coachProvider,
    PreferencesController? preferences,
    AdminReadingsController? adminReadings,
    SmartFootwearHapticService? hapticService,
  }) : repository = repository ?? DemoMovementRepository(),
       studio = studio ?? StudioController(),
       progress = progress ?? ProgressController(),
       preferences = preferences ?? PreferencesController(),
       adminReadings = adminReadings ?? AdminReadingsController(),
       hapticService = hapticService ?? SmartFootwearHapticService() {
    safety = SafetyController(preferences: this.preferences);
    devices = DeviceHubController(
      studio: this.studio,
      preferences: this.preferences,
    );
    this.preferences.addListener(_settingsChanged);
    this.adminReadings.addListener(_adminReadingsChanged);
    devices.addListener(_deviceChanged);
    _adminReadingsChanged();
    this.studio.retainReplay = false;
    this.hapticService.setHardwareCommandHandler(
      (cmd) => this.adminReadings.sendMotorCommand(cmd),
    );
    coach = CoachController(
      studio: this.studio,
      progress: this.progress,
      provider: coachProvider,
    );
  }
  final MovementRepository repository;
  final StudioController studio;
  final ProgressController progress;
  late final CoachController coach;
  final PreferencesController preferences;
  final AdminReadingsController adminReadings;
  final SmartFootwearHapticService hapticService;
  late final SafetyController safety;
  late final DeviceHubController devices;
  void _settingsChanged() {
    studio.retainReplay =
        preferences.ready && preferences.data.settings.retainReplay;
    notifyListeners();
  }

  void _deviceChanged() {
    notifyListeners();
  }

  bool _disposed = false;
  int _refreshGeneration = 0;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ThemeMode themeMode = ThemeMode.dark;
  bool onboarded = false;
  String? storageError;
  PreviewState state = PreviewState.loading;
  DeviceState get device => devices.legacyState;
  DashboardData? data;
  DashboardData? get dashboardData {
    final current = data;
    if (current == null) {
      if (adminReadings.value.adjusted) {
        return DashboardData(
          steps: adminReadings.value.dashboardSteps,
          goal: adminReadings.value.dailyGoal,
          sessions: const [],
        );
      }
      return null;
    }
    if (!adminReadings.value.adjusted) return current;
    return DashboardData(
      steps: adminReadings.value.dashboardSteps,
      goal: adminReadings.value.dailyGoal,
      sessions: current.sessions,
    );
  }

  int _lastHandledFallTriggerId = 0;

  void _adminReadingsChanged() {
    final readings = adminReadings.value;
    studio.setSensorOverrides(
      readings.adjusted ? readings.sensorValues : null,
      stepCount: readings.adjusted ? readings.dashboardSteps : null,
    );

    // If a fall was broadcasted via Firebase:
    if (readings.fallDetected &&
        readings.fallTriggerId > 0 &&
        readings.fallTriggerId != _lastHandledFallTriggerId) {
      if (adminReadings.authenticated) {
        // While user is in Admin mode, defer countdown until they exit to Home screen
      } else {
        _lastHandledFallTriggerId = readings.fallTriggerId;
        safety.startFall();
      }
    }

    notifyListeners();
  }
  SharedPreferences? _preferences;
  Future<void> restore() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      onboarded = _preferences!.getBool('onboarded') ?? false;
      themeMode = (_preferences!.getBool('lightTheme') ?? false)
          ? ThemeMode.light
          : ThemeMode.dark;
    } catch (_) {
      storageError = 'Preferences unavailable. Changes last for this visit.';
    }
    if (_disposed) return;
    await preferences.load();
    if (_disposed) return;
    await studio.loadHistory();
    if (_disposed) return;
    await progress.load();
    if (_disposed) return;
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    state = PreviewState.loading;
    notifyListeners();
    try {
      final result = await repository.loadDashboard();
      if (_disposed || generation != _refreshGeneration) return;
      data = result;
      state = data!.sessions.isEmpty ? PreviewState.empty : PreviewState.ready;
    } catch (_) {
      if (_disposed || generation != _refreshGeneration) return;
      state = PreviewState.error;
    }
    notifyListeners();
  }

  Future<void> _save(String key, bool value) async {
    try {
      if (_preferences == null || !await _preferences!.setBool(key, value)) {
        throw StateError('Storage unavailable');
      }
      storageError = null;
    } catch (_) {
      storageError =
          'Could not save preferences. Your choice is active for this visit.';
    }
    notifyListeners();
  }

  void completeOnboarding() {
    onboarded = true;
    notifyListeners();
    _save('onboarded', true);
  }

  void setLightTheme(bool value) {
    themeMode = value ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _save('lightTheme', value);
  }

  void preview(PreviewState value) {
    state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration++;
    preferences.removeListener(_settingsChanged);
    adminReadings.removeListener(_adminReadingsChanged);
    devices.removeListener(_deviceChanged);
    safety.dispose();
    devices.dispose();
    coach.dispose();
    hapticService.dispose();
    adminReadings.dispose();
    preferences.dispose();
    studio.dispose();
    progress.dispose();
    super.dispose();
  }

  void setDevice(DeviceState value) {
    devices.setPreview(value);
  }
}
