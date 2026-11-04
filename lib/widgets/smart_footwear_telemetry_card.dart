import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/smart_footwear_haptic_service.dart';
import 'components.dart';

class SmartFootwearTelemetryCard extends StatelessWidget {
  const SmartFootwearTelemetryCard({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.adminReadings,
        controller.hapticService,
      ]),
      builder: (context, _) {
        final readings = controller.adminReadings.value;
        final heel = readings.heelADC;
        final midfoot = readings.midfootADC;
        final forefoot = readings.forefootADC;
        final accel = readings.accelerationG;
        final gyro = readings.gyroscopeDPS;
        final isContact = readings.footContact;
        final isFall = readings.fallDetected;
        final mpuStatus = readings.mpuStatus;
        final steps = readings.dashboardSteps;

        return Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: readings.adjusted
                          ? const Color(0xFF00E676)
                          : Colors.orangeAccent,
                      shape: BoxShape.circle,
                      boxShadow: readings.adjusted
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676).withAlpha(180),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SMART FOOTWEAR REALTIME TELEMETRY',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusPill(
                    readings.adjusted ? 'HARDWARE ONLINE' : 'STANDBY',
                  ),
                ],
              ),
              if (controller.adminReadings.error != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.adminReadings.error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Steps & Status Badges
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HARDWARE STEPS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$steps',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: StrideColors.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FOOT CONTACT',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isContact ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 16,
                                color: isContact ? const Color(0xFF00E676) : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isContact ? 'YES' : 'NO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isContact ? const Color(0xFF00E676) : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFall
                            ? Colors.redAccent.withAlpha(50)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: isFall
                            ? Border.all(color: Colors.redAccent, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FALL DETECTED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isFall ? 'YES (FALL ACTIVE)' : 'NO (NORMAL)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isFall ? Colors.redAccent : const Color(0xFF00E676),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MPU6050 STATUS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mpuStatus,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: StrideColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Pressure ADC Sensors
              const Text(
                'PRESSURE SENSORS (0 - 4095 ADC)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              _pressureBar('Heel ADC', heel, StrideColors.mint),
              const SizedBox(height: 8),
              _pressureBar('Midfoot ADC', midfoot, StrideColors.lavender),
              const SizedBox(height: 8),
              _pressureBar('Forefoot ADC', forefoot, StrideColors.blue),
              const SizedBox(height: 18),

              // IMU Motion
              const Text(
                'MPU6050 MOTION INERTIAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Acceleration (g)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            '${accel.toStringAsFixed(2)} g',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gyroscope (dps)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            '${gyro.toStringAsFixed(2)} dps',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Hardware Control Buttons
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'HARDWARE HAPTIC COMMANDS (ESP32 MOTORS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sends live commands to ESP32: L=left motor, R=right motor, F=fall pattern, S=stop',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: StrideColors.mint.withAlpha(40),
                      foregroundColor: StrideColors.mint,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: StrideColors.mint),
                      ),
                    ),
                    onPressed: () async {
                      await controller.adminReadings.sendMotorCommand('L');
                      await controller.hapticService.triggerHaptic(ShoeSide.left);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dispatched: Left Motor Pulse (L)'),
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF1E2838),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Left Motor (L)'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: StrideColors.blue.withAlpha(40),
                      foregroundColor: StrideColors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: StrideColors.blue),
                      ),
                    ),
                    onPressed: () async {
                      await controller.adminReadings.sendMotorCommand('R');
                      await controller.hapticService.triggerHaptic(ShoeSide.right);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dispatched: Right Motor Pulse (R)'),
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF1E2838),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Right Motor (R)'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent.withAlpha(40),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    onPressed: () async {
                      await controller.adminReadings.sendMotorCommand('F');
                      await controller.adminReadings.triggerRemoteFallAlert();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dispatched: Fall Pattern (F)'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.warning, size: 16),
                    label: const Text('Fall Pattern (F)'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await controller.adminReadings.sendMotorCommand('S');
                      controller.hapticService.stopRouteSimulation();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dispatched: Stop All Motors (S)'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Stop (S)'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pressureBar(String label, int value, Color color) {
    final progress = (value / 4095.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '$value ADC  (${(progress * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

