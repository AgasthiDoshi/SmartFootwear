import 'package:flutter/material.dart';
import '../../services/admin_readings_controller.dart';
import '../../services/smart_footwear_haptic_service.dart';
import '../../widgets/gmap_navigation_view.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({
    super.key,
    required this.hapticService,
    this.adminReadings,
  });
  final SmartFootwearHapticService hapticService;
  final AdminReadingsController? adminReadings;

  @override
  Widget build(BuildContext context) {
    return GMapNavigationView(
      hapticService: hapticService,
      adminReadings: adminReadings,
      startInDemoMode: false,
    );
  }
}
