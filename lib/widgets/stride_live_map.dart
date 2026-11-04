import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../services/emergency_dispatch_service.dart';

enum MapTileStyle {
  dark('Dark Matter', 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'),
  street('Street', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  const MapTileStyle(this.label, this.urlTemplate);
  final String label;
  final String urlTemplate;
}

class StrideLiveMap extends StatefulWidget {
  const StrideLiveMap({
    super.key,
    this.height = 320,
    this.showControls = true,
    this.showTelemetryOverlay = true,
    this.trackTrail = true,
    this.initialZoom = 16.0,
    this.destination,
    this.destinationTitle,
    this.onLocationChanged,
  });

  final double height;
  final bool showControls;
  final bool showTelemetryOverlay;
  final bool trackTrail;
  final double initialZoom;
  final LatLng? destination;
  final String? destinationTitle;
  final ValueChanged<Position>? onLocationChanged;

  @override
  State<StrideLiveMap> createState() => _StrideLiveMapState();
}

class _StrideLiveMapState extends State<StrideLiveMap> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Position? _currentPosition;
  LatLng _userLatLng = const LatLng(37.7749, -122.4194); // Fallback SF
  bool _loadingLocation = true;
  String? _locationError;
  MapTileStyle _tileStyle = MapTileStyle.dark;
  final List<LatLng> _trail = [];
  StreamSubscription<Position>? _positionStreamSub;
  double _currentZoom = 16.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentZoom = widget.initialZoom;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 8.0, end: 22.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() => _loadingLocation = true);

    final pos = await EmergencyDispatchService.getCurrentLocation();
    if (!mounted) return;

    if (pos != null) {
      _applyPosition(pos);
      _mapController.move(_userLatLng, _currentZoom);
    } else {
      setState(() {
        _loadingLocation = false;
        _locationError = 'GPS signal unavailable. Using default position.';
      });
    }

    _startLiveStream();
  }

  void _startLiveStream() {
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // notify every 2 meters of movement
      );

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position newPos) {
          if (!mounted) return;
          _applyPosition(newPos);
        },
        onError: (e) {
          debugPrint('Live GPS stream notice: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not start live GPS stream: $e');
    }
  }

  void _applyPosition(Position pos) {
    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _currentPosition = pos;
      _userLatLng = latLng;
      _loadingLocation = false;
      _locationError = null;

      if (widget.trackTrail) {
        if (_trail.isEmpty || _trail.last != latLng) {
          _trail.add(latLng);
        }
      }
    });

    widget.onLocationChanged?.call(pos);
  }

  void _recenter() {
    _mapController.move(_userLatLng, 16.5);
  }

  void _zoomIn() {
    setState(() => _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0));
    _mapController.move(_userLatLng, _currentZoom);
  }

  void _zoomOut() {
    setState(() => _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0));
    _mapController.move(_userLatLng, _currentZoom);
  }

  void _toggleTileStyle() {
    setState(() {
      _tileStyle = _tileStyle == MapTileStyle.dark
          ? MapTileStyle.street
          : MapTileStyle.dark;
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Live Interactive FlutterMap with OpenStreetMap / CartoDB tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLatLng,
              initialZoom: _currentZoom,
              minZoom: 3.0,
              maxZoom: 19.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileStyle.urlTemplate,
                userAgentPackageName: 'com.strideai.stride_ai',
                maxZoom: 19,
              ),

              // Walking Breadcrumb Trail Polyline
              if (widget.trackTrail && _trail.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trail,
                      color: StrideColors.mint,
                      strokeWidth: 4.5,
                      borderColor: Colors.black45,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Destination Route if specified
              if (widget.destination != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userLatLng, widget.destination!],
                      color: Colors.cyanAccent.withAlpha(200),
                      strokeWidth: 3.5,
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
                    ),
                  ],
                ),

              // User Live GPS Marker Layer
              MarkerLayer(
                markers: [
                  // Destination marker if any
                  if (widget.destination != null)
                    Marker(
                      point: widget.destination!,
                      width: 48,
                      height: 48,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyanAccent),
                            ),
                            child: Text(
                              widget.destinationTitle ?? 'Goal',
                              style: const TextStyle(fontSize: 9, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.location_on, color: Colors.cyanAccent, size: 28),
                        ],
                      ),
                    ),

                  // LIVE USER PULSING MARKER
                  Marker(
                    point: _userLatLng,
                    width: 72,
                    height: 72,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulsing Glow Ring
                          Container(
                            width: _pulseAnimation.value * 2.2,
                            height: _pulseAnimation.value * 2.2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: StrideColors.blue.withAlpha(60),
                              border: Border.all(
                                color: StrideColors.blue.withAlpha(160),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Middle White Halo
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          // Core Vibrant Blue/Mint Dot
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF007BFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Loading Indicator / Error Banner
          if (_loadingLocation)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: StrideColors.mint),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Acquiring live GPS fix…',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          if (_locationError != null && !_loadingLocation)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orangeAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Text(
                      _locationError!,
                      style: const TextStyle(fontSize: 10, color: Colors.orangeAccent),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Floating Map Controls (Zoom, Recenter, Style)
          if (widget.showControls)
            Positioned(
              right: 12,
              bottom: widget.showTelemetryOverlay ? 64 : 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _mapButton(
                    icon: Icons.my_location,
                    tooltip: 'Recenter on My Location',
                    color: StrideColors.mint,
                    onPressed: _recenter,
                  ),
                  const SizedBox(height: 8),
                  _mapButton(
                    icon: Icons.add,
                    tooltip: 'Zoom In',
                    onPressed: _zoomIn,
                  ),
                  const SizedBox(height: 8),
                  _mapButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom Out',
                    onPressed: _zoomOut,
                  ),
                  const SizedBox(height: 8),
                  _mapButton(
                    icon: _tileStyle == MapTileStyle.dark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                    tooltip: 'Toggle Style (${_tileStyle.label})',
                    onPressed: _toggleTileStyle,
                  ),
                ],
              ),
            ),

          // 4. Bottom Live GPS Telemetry Bar
          if (widget.showTelemetryOverlay)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D).withAlpha(235),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed, size: 15, color: StrideColors.mint),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_userLatLng.latitude.toStringAsFixed(4)}°, ${_userLatLng.longitude.toStringAsFixed(4)}°',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              _currentPosition != null
                                  ? 'Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m'
                                  : 'GPS Active',
                              style: const TextStyle(fontSize: 10, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_currentPosition != null && _currentPosition!.speed > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: StrideColors.blue.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: StrideColors.blue),
                        ),
                        child: Text(
                          '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StrideColors.blue),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return Material(
      color: const Color(0xFF161B26).withAlpha(230),
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
