import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ShoeSide { left, right, both, none }

enum NavigationManeuver {
  start('Starting route', 'Begin walking along route', ShoeSide.both),
  straight('Straight ahead', 'Continue straight for 150m', ShoeSide.none),
  turnLeft('Turn Left', 'Turn Left in 30m onto Park Avenue', ShoeSide.left),
  turnRight('Turn Right', 'Turn Right in 25m onto Oak Boulevard', ShoeSide.right),
  slightLeft('Bear Left', 'Slight left onto pedestrian trail', ShoeSide.left),
  slightRight('Bear Right', 'Slight right towards destination', ShoeSide.right),
  arrived('Arrived at Destination', 'You have reached your destination', ShoeSide.both);

  const NavigationManeuver(this.title, this.instructions, this.recommendedShoe);
  final String title;
  final String instructions;
  final ShoeSide recommendedShoe;
}

class SmartFootwearHapticService extends ChangeNotifier {
  SmartFootwearHapticService({this.onHardwareMotorCommand});

  Future<void> Function(String command)? onHardwareMotorCommand;

  void setHardwareCommandHandler(Future<void> Function(String command)? handler) {
    onHardwareMotorCommand = handler;
  }

  bool _isLeftVibrating = false;
  bool _isRightVibrating = false;
  Timer? _vibrationTimer;

  bool get isLeftVibrating => _isLeftVibrating;
  bool get isRightVibrating => _isRightVibrating;

  NavigationManeuver currentManeuver = NavigationManeuver.straight;
  int currentStepIndex = 0;
  bool isSimulatingRoute = false;
  Timer? _simulationTimer;

  // BLE Hardware Command Bridge (Ready for real hardware insole pairing)
  List<int> lastBlePayload = [];

  /// Trigger haptic vibration on left, right, or both smart footwear shoes.
  Future<void> triggerHaptic(ShoeSide side, {int durationMs = 600}) async {
    _vibrationTimer?.cancel();

    _isLeftVibrating = side == ShoeSide.left || side == ShoeSide.both;
    _isRightVibrating = side == ShoeSide.right || side == ShoeSide.both;
    notifyListeners();

    // 1. Device physical haptic feedback
    try {
      if (side == ShoeSide.left || side == ShoeSide.right) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.heavyImpact();
      } else if (side == ShoeSide.both) {
        await HapticFeedback.vibrate();
      }
    } catch (_) {}

    // 2. Hardware BLE bridge packet (for connecting to ESP32 / Arduino / BLE footwear later)
    // Packet format: [Header (0x53='S', 0x46='F'), Side (1=L, 2=R, 3=Both), Duration (ms / 10)]
    final sideByte = side == ShoeSide.left ? 0x01 : (side == ShoeSide.right ? 0x02 : 0x03);
    lastBlePayload = [0x53, 0x46, sideByte, (durationMs ~/ 10)];
    debugPrint('Smart Footwear Haptic BLE Bridge dispatch: $side (Payload: $lastBlePayload)');

    // 3. Hardware Firebase / Realtime Database motor dispatch
    if (side == ShoeSide.left) {
      onHardwareMotorCommand?.call('L');
    } else if (side == ShoeSide.right) {
      onHardwareMotorCommand?.call('R');
    } else if (side == ShoeSide.both) {
      onHardwareMotorCommand?.call('F');
    }

    _vibrationTimer = Timer(Duration(milliseconds: durationMs), () {
      _isLeftVibrating = false;
      _isRightVibrating = false;
      onHardwareMotorCommand?.call('S');
      notifyListeners();
    });
  }

  /// Dispatch maneuver direction guidance to shoes.
  Future<void> setManeuver(NavigationManeuver maneuver) async {
    currentManeuver = maneuver;
    notifyListeners();

    if (maneuver.recommendedShoe != ShoeSide.none) {
      await triggerHaptic(maneuver.recommendedShoe);
    }
  }

  /// Start step-by-step navigation walk simulation.
  void startRouteSimulation() {
    isSimulatingRoute = true;
    currentStepIndex = 0;
    notifyListeners();

    final maneuvers = [
      NavigationManeuver.start,
      NavigationManeuver.straight,
      NavigationManeuver.turnRight, // Right shoe vibrates!
      NavigationManeuver.straight,
      NavigationManeuver.turnLeft,  // Left shoe vibrates!
      NavigationManeuver.slightRight, // Right shoe vibrates!
      NavigationManeuver.arrived,  // Both shoes pulse!
    ];

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!isSimulatingRoute) {
        timer.cancel();
        return;
      }
      currentStepIndex++;
      if (currentStepIndex >= maneuvers.length) {
        currentStepIndex = 0;
      }
      setManeuver(maneuvers[currentStepIndex]);
    });

    setManeuver(maneuvers[0]);
  }

  void stopRouteSimulation() {
    isSimulatingRoute = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    currentManeuver = NavigationManeuver.straight;
    _isLeftVibrating = false;
    _isRightVibrating = false;
    onHardwareMotorCommand?.call('S');
    notifyListeners();
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}
