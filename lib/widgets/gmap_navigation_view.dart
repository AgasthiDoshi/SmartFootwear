import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/admin_readings_controller.dart';
import '../services/emergency_dispatch_service.dart';
import '../services/smart_footwear_haptic_service.dart';

// ---------------------------------------------------------------------------
// Demo route: a realistic ~1 km loop with named turns.
// ---------------------------------------------------------------------------

class _RouteStep {
  const _RouteStep({
    required this.instruction,
    required this.streetName,
    required this.distanceM,
    required this.maneuver,
    this.icon = Icons.arrow_upward_rounded,
  });
  final String instruction;
  final String streetName;
  final int distanceM;
  final NavigationManeuver maneuver;
  final IconData icon;
}

const List<_RouteStep> _demoSteps = [
  _RouteStep(
    instruction: 'Head north',
    streetName: 'Main Street',
    distanceM: 120,
    maneuver: NavigationManeuver.start,
    icon: Icons.arrow_upward_rounded,
  ),
  _RouteStep(
    instruction: 'Turn right onto',
    streetName: 'Park Avenue',
    distanceM: 90,
    maneuver: NavigationManeuver.turnRight,
    icon: Icons.turn_right_rounded,
  ),
  _RouteStep(
    instruction: 'Continue straight on',
    streetName: 'Park Avenue',
    distanceM: 200,
    maneuver: NavigationManeuver.straight,
    icon: Icons.straight_rounded,
  ),
  _RouteStep(
    instruction: 'Turn left onto',
    streetName: 'Oak Boulevard',
    distanceM: 80,
    maneuver: NavigationManeuver.turnLeft,
    icon: Icons.turn_left_rounded,
  ),
  _RouteStep(
    instruction: 'Bear right onto',
    streetName: 'Forest Trail',
    distanceM: 150,
    maneuver: NavigationManeuver.slightRight,
    icon: Icons.turn_slight_right_rounded,
  ),
  _RouteStep(
    instruction: 'Bear left onto',
    streetName: 'Meadow Path',
    distanceM: 100,
    maneuver: NavigationManeuver.slightLeft,
    icon: Icons.turn_slight_left_rounded,
  ),
  _RouteStep(
    instruction: 'You have arrived at',
    streetName: 'Central Park Trail',
    distanceM: 0,
    maneuver: NavigationManeuver.arrived,
    icon: Icons.flag_rounded,
  ),
];

/// Builds a demo polyline route around a given origin.
///
/// Geometry is designed so that the turn at each waypoint exactly
/// matches the corresponding _demoSteps instruction:
///
///   0 → 1 : NORTH           "Head north"
///   1 → 2 : EAST            "Turn right"    (north → east = right)
///   2 → 3 : EAST            "Straight"      (east  → east = straight)
///   3 → 4 : NORTH           "Turn left"     (east  → north = left)
///   4 → 5 : NORTH-EAST      "Bear right"    (north → NE   = slight right)
///   5 → 6 : NORTH-WEST      "Bear left"     (NE    → NW   = slight left)
///   6     : DESTINATION      "Arrived"
///
List<LatLng> _buildDemoRoute(LatLng origin) {
  const double d = 0.001; // ≈111 m per 0.001° lat
  return [
    origin,                                                  // 0  Start
    LatLng(origin.latitude + d * 1.2, origin.longitude),     // 1  North
    LatLng(origin.latitude + d * 1.2, origin.longitude + d * 1.5), // 2  East
    LatLng(origin.latitude + d * 1.2, origin.longitude + d * 3.5), // 3  East (straight)
    LatLng(origin.latitude + d * 2.8, origin.longitude + d * 3.5), // 4  North (left)
    LatLng(origin.latitude + d * 3.5, origin.longitude + d * 4.5), // 5  NE (bear right)
    LatLng(origin.latitude + d * 4.2, origin.longitude + d * 3.8), // 6  NW (bear left) = dest
  ];
}

// ---------------------------------------------------------------------------
// Google-Maps–look-alike colours
// ---------------------------------------------------------------------------
const Color _gmGreen = Color(0xFF1A9850);   // nav header
const Color _gmBlue = Color(0xFF4285F4);    // route polyline
const Color _gmText = Color(0xFF212121);
const Color _gmSubText = Color(0xFF616161);
const Color _gmRed = Color(0xFFD32F2F);

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class GMapNavigationView extends StatefulWidget {
  const GMapNavigationView({
    super.key,
    required this.hapticService,
    this.adminReadings,
    this.startInDemoMode = false,
  });

  final SmartFootwearHapticService hapticService;
  final AdminReadingsController? adminReadings;
  final bool startInDemoMode;

  @override
  State<GMapNavigationView> createState() => _GMapNavigationViewState();
}

class _GMapNavigationViewState extends State<GMapNavigationView>
    with TickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────────
  late final MapController _mapController;
  LatLng _userLatLng = const LatLng(28.6139, 77.2090); // Delhi default
  List<LatLng> _routePoints = [];
  List<LatLng> _travelledPoints = [];
  StreamSubscription<Position>? _gpsSub;
  bool _locationReady = false;   // set true once GPS confirmed

  // ── Demo playback ────────────────────────────────────────────────────────
  bool _demoMode = false;
  bool _demoRunning = false;
  int _demoRouteIdx = 0;
  Timer? _demoStepTimer;
  Timer? _demoMoveTimer;

  // ── Navigation state ─────────────────────────────────────────────────────
  int _stepIdx = 0;
  _RouteStep get _currentStep => _demoSteps[_stepIdx.clamp(0, _demoSteps.length - 1)];
  bool get _arrived => _stepIdx >= _demoSteps.length - 1;

  // ── Distance countdown ───────────────────────────────────────────────────
  int _distanceLeft = _demoSteps.first.distanceM;
  Timer? _distanceTimer;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _arrowPulse;
  late AnimationController _vibPulse;

  // ── Search bar ───────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController(
    text: 'Central Park Trail',
  );

  // ── Tile style ───────────────────────────────────────────────────────────
  bool _satelliteMode = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _arrowPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _vibPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _demoMode = widget.startInDemoMode;
    _initGps();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _initGps() async {
    final pos = await EmergencyDispatchService.getCurrentLocation();
    if (!mounted) return;
    if (pos != null) {
      _setLocation(LatLng(pos.latitude, pos.longitude));
    }
    _startGpsStream();
  }

  void _startGpsStream() {
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((p) {
      if (!mounted) return;
      if (!_demoMode) {
        _setLocation(LatLng(p.latitude, p.longitude));
      }
    });
  }

  void _setLocation(LatLng ll) {
    setState(() {
      _userLatLng = ll;
      _locationReady = true;
      _routePoints = _buildDemoRoute(ll);
      _travelledPoints = [ll];
    });
    _mapController.move(ll, 17.0);
  }

  // ── Demo mode ────────────────────────────────────────────────────────────

  /// Intermediate interpolated points between each pair of waypoints so
  /// the marker glides smoothly.  We place [_interpCount] sub-steps
  /// between consecutive waypoints.
  static const int _interpCount = 5;
  List<LatLng> _smoothRoute = [];
  int _smoothIdx = 0;

  /// Build a smooth route with interpolated sub-points from the waypoints.
  void _buildSmoothRoute() {
    _smoothRoute = [];
    for (int i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      for (int j = 0; j < _interpCount; j++) {
        final t = j / _interpCount;
        _smoothRoute.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    // add final destination point
    _smoothRoute.add(_routePoints.last);
  }

  /// Returns which waypoint segment (0-based) a smooth-route index belongs to.
  int _waypointForSmoothIdx(int idx) {
    if (_routePoints.length <= 1) return 0;
    final seg = idx ~/ _interpCount;
    return seg.clamp(0, _routePoints.length - 1);
  }

  void _startDemo() {
    if (_routePoints.isEmpty) {
      _routePoints = _buildDemoRoute(_userLatLng);
    }
    _buildSmoothRoute();
    setState(() {
      _demoRunning = true;
      _demoRouteIdx = 0;
      _smoothIdx = 0;
      _stepIdx = 0;
      _distanceLeft = _currentStep.distanceM;
      _travelledPoints = [_routePoints.first];
      _userLatLng = _routePoints.first;
    });
    _mapController.move(_routePoints.first, 17.5);

    // Single unified timer – moves marker AND advances step in sync.
    _demoMoveTimer?.cancel();
    _demoMoveTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!_demoRunning || _smoothRoute.isEmpty) return;

      // Advance smooth index
      if (_smoothIdx < _smoothRoute.length - 1) {
        _smoothIdx++;
      } else {
        // Reached end of route
        _onStepChanged(_demoSteps.length - 1);
        _stopDemo();
        return;
      }

      final next = _smoothRoute[_smoothIdx];
      final newWaypoint = _waypointForSmoothIdx(_smoothIdx);
      final prevWaypoint = _demoRouteIdx;

      setState(() {
        _userLatLng = next;
        _travelledPoints = _smoothRoute.sublist(0, _smoothIdx + 1);
        _demoRouteIdx = newWaypoint;

        // Decrease distance counter smoothly
        if (_distanceLeft > 0) {
          _distanceLeft = (_distanceLeft - (_currentStep.distanceM / _interpCount).round())
              .clamp(0, 99999);
        }
      });
      _mapController.move(next, 17.5);

      // Step changed when the marker crosses into a new waypoint segment
      if (newWaypoint != prevWaypoint && newWaypoint < _demoSteps.length) {
        _onStepChanged(newWaypoint);
      }
    });

    // Trigger haptic for first step
    _triggerHapticForStep(_currentStep);
  }

  void _onStepChanged(int newStep) {
    if (newStep == _stepIdx) return;
    setState(() {
      _stepIdx = newStep.clamp(0, _demoSteps.length - 1);
      _distanceLeft = _currentStep.distanceM;
    });
    _triggerHapticForStep(_currentStep);

    // Restart arrow pulse for visual emphasis
    _arrowPulse
      ..reset()
      ..repeat(reverse: true);
  }

  void _advanceDemoStep() {
    if (_stepIdx >= _demoSteps.length - 1) {
      _stopDemo();
      return;
    }
    _onStepChanged(_stepIdx + 1);
  }

  Future<void> _dispatchMotor(String cmd) async {
    // 1. Direct hardware dispatch to Firebase Realtime Database
    await widget.adminReadings?.sendMotorCommand(cmd);

    // 2. Trigger Haptic Service (phone heavy impact vibration + UI glow badge)
    if (cmd == 'L') {
      await widget.hapticService.triggerHaptic(ShoeSide.left);
    } else if (cmd == 'R') {
      await widget.hapticService.triggerHaptic(ShoeSide.right);
    } else if (cmd == 'F') {
      await widget.hapticService.triggerHaptic(ShoeSide.both);
    } else if (cmd == 'S') {
      widget.hapticService.stopRouteSimulation();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cmd == 'L'
                ? '⚡ Left Shoe Motor Pulsing (PIN 18)'
                : (cmd == 'R'
                    ? '⚡ Right Shoe Motor Pulsing (PIN 19)'
                    : '⚡ Stop Command Sent'),
          ),
          duration: const Duration(milliseconds: 900),
          backgroundColor: const Color(0xFF1B2434),
        ),
      );
    }
  }

  void _triggerHapticForStep(_RouteStep step) {
    widget.hapticService.setManeuver(step.maneuver);

    // Dual-dispatch to Firebase ensuring physical insole motor responds immediately
    if (step.maneuver.recommendedShoe == ShoeSide.left) {
      widget.adminReadings?.sendMotorCommand('L');
    } else if (step.maneuver.recommendedShoe == ShoeSide.right) {
      widget.adminReadings?.sendMotorCommand('R');
    } else if (step.maneuver.recommendedShoe == ShoeSide.both) {
      widget.adminReadings?.sendMotorCommand('F');
    }

    // Pulse vibration indicator
    _vibPulse
      ..reset()
      ..forward();
  }

  void _stopDemo() {
    _demoMoveTimer?.cancel();
    _demoStepTimer?.cancel();
    _distanceTimer?.cancel();
    setState(() {
      _demoRunning = false;
      _stepIdx = 0;
      _distanceLeft = _demoSteps.first.distanceM;
    });
    widget.hapticService.stopRouteSimulation();
  }

  void _toggleDemoMode() {
    setState(() => _demoMode = !_demoMode);
    if (_demoMode) {
      _startDemo();
    } else {
      _stopDemo();
    }
  }

  // ── Colour helpers ───────────────────────────────────────────────────────

  Color get _stepAccentColor {
    final shoe = _currentStep.maneuver.recommendedShoe;
    if (shoe == ShoeSide.left) return Colors.cyanAccent;
    if (shoe == ShoeSide.right) return Colors.pinkAccent;
    if (shoe == ShoeSide.both) return _gmGreen;
    return Colors.white;
  }

  Color get _headerColor {
    if (_arrived) return _gmGreen;
    final shoe = _currentStep.maneuver.recommendedShoe;
    if (shoe == ShoeSide.left) return const Color(0xFF0077B6);
    if (shoe == ShoeSide.right) return const Color(0xFF7B2D8B);
    return _gmGreen;
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _gpsSub?.cancel();
    _demoMoveTimer?.cancel();
    _demoStepTimer?.cancel();
    _distanceTimer?.cancel();
    _arrowPulse.dispose();
    _vibPulse.dispose();
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.hapticService,
      builder: (context, _) => _buildView(),
    );
  }

  Widget _buildView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Map fills entire screen ──────────────────────────────────
          _buildMap(),

          // ── 2. Top Navigation Banner (Google Maps green card style) ─────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                  if (_demoRunning || !_demoMode) _buildNavBanner(),
                ],
              ),
            ),
          ),

          // ── 3. ETA / Distance Summary Bar (bottom, Google Maps style) ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),

          // ── 4. Floating Map Controls (right side) ───────────────────────
          Positioned(
            right: 12,
            bottom: 130,
            child: _buildRightControls(),
          ),

          // ── GPS acquiring indicator ─────────────────────────────────────
          if (!_locationReady)
            Positioned(
              top: 180,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Acquiring GPS fix…',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 5. Haptic Shoe Indicator (top-right corner) ─────────────────
          Positioned(
            top: 168,
            right: 12,
            child: _buildHapticIndicator(),
          ),
        ],
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final routeCompleted = _travelledPoints.length >= 2;
    final routeAhead = _demoRouteIdx < _routePoints.length - 1
        ? _routePoints.sublist(_demoRouteIdx)
        : <LatLng>[];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLatLng,
        initialZoom: 17.0,
        minZoom: 3,
        maxZoom: 19,
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: _satelliteMode
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.strideai.stride_ai',
          maxZoom: 19,
        ),

        // Route ahead — blue (Google Maps style)
        if (routeAhead.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: routeAhead,
              color: _gmBlue,
              strokeWidth: 9,
              borderColor: Colors.white.withAlpha(120),
              borderStrokeWidth: 2,
            ),
          ]),

        // Travelled path — faded
        if (routeCompleted)
          PolylineLayer(polylines: [
            Polyline(
              points: _travelledPoints,
              color: Colors.grey.withAlpha(160),
              strokeWidth: 7,
            ),
          ]),

        // Turn Arrows on route waypoints
        if (_routePoints.isNotEmpty) _buildRouteArrows(),

        // Start pin
        if (_routePoints.isNotEmpty)
          MarkerLayer(markers: [
            _buildStartMarker(_routePoints.first),
            _buildDestMarker(_routePoints.last),
            _buildUserMarker(),
          ]),
      ],
    );
  }

  Widget _buildRouteArrows() {
    // Place turn-indicator chevrons at each waypoint.
    // Current step → blue highlight, past → grey, future → white.
    final waypoints = _routePoints;
    final markers = <Marker>[];
    for (int i = 1; i < waypoints.length - 1 && i < _demoSteps.length; i++) {
      final step = _demoSteps[i];
      final isCurrent = i == _stepIdx;
      final isPast = i < _stepIdx;
      final isNext = i == _stepIdx + 1;
      final Color bg;
      final Color fg;
      if (isCurrent) {
        bg = _gmBlue;
        fg = Colors.white;
      } else if (isNext) {
        bg = Colors.white;
        fg = _gmBlue;
      } else if (isPast) {
        bg = Colors.grey.shade400;
        fg = Colors.white;
      } else {
        bg = Colors.white;
        fg = _gmBlue.withAlpha(160);
      }
      markers.add(Marker(
        point: waypoints[i],
        width: 34,
        height: 34,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.white, width: 2.5) : null,
            boxShadow: [
              BoxShadow(
                color: isCurrent ? _gmBlue.withAlpha(180) : Colors.black38,
                blurRadius: isCurrent ? 10 : 4,
                spreadRadius: isCurrent ? 2 : 0,
              ),
            ],
          ),
          child: Icon(step.icon, size: 18, color: fg),
        ),
      ));
    }
    return MarkerLayer(markers: markers);
  }

  Marker _buildUserMarker() {
    return Marker(
      point: _userLatLng,
      width: 80,
      height: 80,
      child: AnimatedBuilder(
        animation: _vibPulse,
        builder: (context, _) {
          final vibrating = widget.hapticService.isLeftVibrating ||
              widget.hapticService.isRightVibrating;
          final scale = vibrating
              ? 1.0 + _vibPulse.value * 0.35
              : 1.0;
          final ringColor = _stepAccentColor;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing accuracy ring
              AnimatedBuilder(
                animation: _arrowPulse,
                builder: (context, _) => Container(
                  width: 46 + _arrowPulse.value * 10,
                  height: 46 + _arrowPulse.value * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gmBlue.withAlpha(30),
                    border: Border.all(
                      color: _gmBlue.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // White halo
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Blue core
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vibrating ? ringColor : _gmBlue,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _buildStartMarker(LatLng point) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _gmGreen,
        ),
        child: const Icon(Icons.directions_walk, color: Colors.white, size: 20),
      ),
    );
  }

  Marker _buildDestMarker(LatLng point) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _gmRed,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Goal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(Icons.location_on, color: _gmRed, size: 28),
        ],
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _gmSubText),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                  color: _gmText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search destination…',
                  hintStyle: TextStyle(color: _gmSubText),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: _demoMode ? 'Demo Mode ON' : 'Demo Mode OFF',
              icon: Icon(
                _demoMode ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
                color: _demoMode ? _gmGreen : _gmSubText,
              ),
              onPressed: _toggleDemoMode,
            ),
            IconButton(
              tooltip: 'Microphone',
              icon: const Icon(Icons.mic_rounded, color: _gmSubText),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation Banner ────────────────────────────────────────────────────

  Widget _buildNavBanner() {
    if (!_demoMode && !_demoRunning) {
      // Static "Ready to navigate" banner
      return _buildIdleBanner();
    }
    if (_arrived) return _buildArrivedBanner();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _headerColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _headerColor.withAlpha(140),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big turn arrow
              AnimatedBuilder(
                animation: _arrowPulse,
                builder: (context, _) => Transform.scale(
                  scale: 0.9 + _arrowPulse.value * 0.12,
                  child: Icon(
                    _currentStep.icon,
                    color: Colors.white,
                    size: 52,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance
                    Text(
                      _distanceLeft > 0
                          ? '$_distanceLeft m'
                          : 'Now',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Instruction
                    Text(
                      _currentStep.instruction,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Street name
                    Text(
                      _currentStep.streetName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Next step preview (Google Maps mini card top right)
              if (_stepIdx + 1 < _demoSteps.length)
                _buildNextStepMini(_demoSteps[_stepIdx + 1]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextStepMini(_RouteStep next) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(next.icon, color: Colors.white, size: 20),
          const SizedBox(height: 2),
          Text(
            '${next.distanceM} m',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _gmGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _gmGreen.withAlpha(120), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Footwear Navigation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Enable Demo Mode to simulate turn-by-turn haptic guidance',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_demoMode)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _gmGreen,
              ),
              onPressed: _startDemo,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildArrivedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gmGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _gmGreen.withAlpha(160), blurRadius: 16)],
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have arrived!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Central Park Trail',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _stopDemo,
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom ETA Bar ───────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final totalSteps = _demoSteps.length;
    final progressRatio = (_stepIdx + 1) / totalSteps;
    final stepsLeft = totalSteps - 1 - _stepIdx;
    final estMin = (stepsLeft * 5).clamp(0, 60);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Route step progress bar (like Google Maps remaining bar)
        LinearProgressIndicator(
          value: progressRatio,
          minHeight: 4,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(_gmBlue),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ETA row
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estMin > 0 ? '$estMin min' : 'Arrived',
                        style: const TextStyle(
                          color: _gmText,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${(stepsLeft * 0.09).toStringAsFixed(2)} km · via Trail',
                        style: const TextStyle(
                          color: _gmSubText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Demo start/stop
                  if (_demoMode)
                    Column(
                      children: [
                        _demoRunning
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _gmRed,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 40),
                                ),
                                onPressed: _stopDemo,
                                icon: const Icon(Icons.stop_rounded, size: 18),
                                label: const Text('Stop'),
                              )
                            : FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _gmGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 40),
                                ),
                                onPressed: _startDemo,
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('Demo'),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          'Demo Mode',
                          style: TextStyle(
                            fontSize: 10,
                            color: _gmSubText,
                          ),
                        ),
                      ],
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _gmGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(130, 44),
                      ),
                      onPressed: () {
                        setState(() => _demoMode = true);
                        _startDemo();
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Start Demo Route'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Step breadcrumbs row
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _demoSteps.length,
                  separatorBuilder: (context, _) => const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _gmSubText,
                  ),
                  itemBuilder: (_, i) {
                    final s = _demoSteps[i];
                    final isCurrent = i == _stepIdx;
                    final isPast = i < _stepIdx;
                    return Tooltip(
                      message: '${s.instruction} ${s.streetName}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _gmBlue
                              : (isPast ? Colors.grey.shade300 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          s.icon,
                          size: 18,
                          color: isCurrent
                              ? Colors.white
                              : (isPast ? Colors.grey : _gmBlue),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Right Controls ───────────────────────────────────────────────────────

  Widget _buildRightControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _gmButton(
          icon: Icons.my_location_rounded,
          color: _gmBlue,
          tooltip: 'Recenter',
          onTap: () => _mapController.move(_userLatLng, 17.5),
        ),
        const SizedBox(height: 8),
        _gmButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom In',
          onTap: () {
            final z = (_mapController.camera.zoom + 1).clamp(3.0, 19.0);
            _mapController.move(_userLatLng, z);
          },
        ),
        const SizedBox(height: 8),
        _gmButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom Out',
          onTap: () {
            final z = (_mapController.camera.zoom - 1).clamp(3.0, 19.0);
            _mapController.move(_userLatLng, z);
          },
        ),
        const SizedBox(height: 8),
        _gmButton(
          icon: _satelliteMode ? Icons.map_rounded : Icons.satellite_alt_rounded,
          tooltip: _satelliteMode ? 'Street View' : 'Satellite',
          onTap: () => setState(() => _satelliteMode = !_satelliteMode),
        ),
        if (_demoMode) ...[
          const SizedBox(height: 8),
          _gmButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next Step',
            color: _stepAccentColor,
            onTap: _advanceDemoStep,
          ),
        ],
      ],
    );
  }

  Widget _gmButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = _gmText,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }

  // ── Interactive Haptic Shoe Buttons & Indicators ──────────────────────────

  Widget _buildHapticIndicator() {
    final leftVib = widget.hapticService.isLeftVibrating;
    final rightVib = widget.hapticService.isRightVibrating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _shoeChip(
          label: 'L',
          subtitle: 'LEFT',
          active: leftVib,
          accentColor: Colors.cyanAccent,
          tooltip: 'Vibrate Left Insole Motor (Pin 18)',
          onTap: () => _dispatchMotor('L'),
        ),
        const SizedBox(height: 8),
        _shoeChip(
          label: 'R',
          subtitle: 'RIGHT',
          active: rightVib,
          accentColor: Colors.pinkAccent,
          tooltip: 'Vibrate Right Insole Motor (Pin 19)',
          onTap: () => _dispatchMotor('R'),
        ),
      ],
    );
  }

  Widget _shoeChip({
    required String label,
    required String subtitle,
    required bool active,
    required Color accentColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? accentColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: active ? accentColor.withAlpha(220) : Colors.black38,
                  blurRadius: active ? 16 : 6,
                  spreadRadius: active ? 3 : 1,
                ),
              ],
              border: Border.all(
                color: active ? accentColor : Colors.grey.shade400,
                width: active ? 2.5 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.black : _gmText,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: active ? Colors.black87 : _gmSubText,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
