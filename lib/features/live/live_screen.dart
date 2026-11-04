import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/studio_controller.dart';
import '../../domain/sensor.dart';
import '../../core/app_controller.dart';
import '../../widgets/smart_footwear_telemetry_card.dart';
import '../../widgets/components.dart';
import '../../core/theme.dart';
import 'insole_view.dart';
import 'sensor_chart.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({
    super.key,
    required this.studio,
    this.controller,
    this.onConnectionChanged,
  });
  final StudioController studio;
  final AppController? controller;
  final ValueChanged<bool>? onConnectionChanged;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: studio,
    builder: (context, _) {
      final busy =
          studio.phase == SessionPhase.saving ||
          studio.phase == SessionPhase.unsaved;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'LIVE SENSOR STUDIO',
            style: TextStyle(fontSize: 11, letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          const Text(
            'Feel the rhythm.',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text('One virtual insole. Every signal in view.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              const StatusPill('LIVE SENSORS · 20 HZ'),
              StatusPill(
                studio.connected
                    ? studio.running
                          ? 'STREAMING'
                          : (studio.sensorOverrides != null ? 'HARDWARE ONLINE' : 'READY')
                    : 'DISCONNECTED',
              ),
            ],
          ),
          const Text(
            'FSR sensor channels and MPU6050 6-axis IMU active.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simulated connection'),
                  value: studio.connected,
                  onChanged: busy
                      ? null
                      : (onConnectionChanged ?? studio.setConnected),
                ),
                Wrap(
                  spacing: 8,
                  children: MotionPattern.values
                      .map(
                        (p) => ChoiceChip(
                          label: Text(
                            p == MotionPattern.walking
                                ? 'Walking'
                                : 'Stationary',
                          ),
                          selected: studio.pattern == p,
                          onSelected:
                              !studio.connected || studio.calibrating || busy
                              ? null
                              : (_) => studio.setPattern(p),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: !studio.connected || busy
                      ? null
                      : studio.running
                      ? studio.stopFeed
                      : studio.startFeed,
                  icon: Icon(studio.running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    studio.running ? 'Pause sensor stream' : 'Start simulation',
                  ),
                ),
                if (!studio.connected)
                  const Text(
                    'Signal lost. Recording is paused. Reconnect, then resume manually.',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (controller != null) ...[
            SmartFootwearTelemetryCard(controller: controller!),
            const SizedBox(height: 20),
          ],
          _SessionControls(studio: studio),
          const SizedBox(height: 24),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading('Pressure in motion'),
                const Text(
                  'Toe → forefoot → heel · display scale 0–2500 ADC',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 20),
                InsoleView(frame: studio.latest),
                const SizedBox(height: 18),
                Text(
                  studio.calibrationMessage,
                  style: const TextStyle(fontSize: 12),
                ),
                if (studio.calibrating) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: studio.calibrationProgress),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed:
                          studio.connected && !studio.sessionActive && !busy
                          ? studio.calibrating
                                ? studio.stopFeed
                                : studio.calibrate
                          : null,
                      child: Text(
                        studio.calibrating
                            ? 'Cancel calibration'
                            : 'Calibrate sensors',
                      ),
                    ),
                    TextButton(
                      onPressed:
                          !studio.sessionActive &&
                              !studio.calibrating &&
                              !busy &&
                              studio.calibrated
                          ? studio.resetCalibration
                          : null,
                      child: const Text('Reset baseline'),
                    ),
                  ],
                ),
                const Text(
                  'Calibration switches the simulator to an unloaded, motionless pose for 40 samples (2 s). It subtracts FSR/gyro offsets and accelerometer bias while retaining 1 g on Z. Calibrate between sessions.',
                  style: TextStyle(fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeading(
            'Signal window',
            action: 'Gait insights',
            onTap: () => context.push('/gait'),
          ),
          const Text(
            'Last 120 samples · 6 seconds · fixed, clipped ranges',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (studio.chart.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Start simulation to see pressure and motion traces.',
              ),
            ),
          Surface(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600
                    ? 3
                    : constraints.maxWidth >= 380
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  children: List.generate(
                    9,
                    (i) => SizedBox(
                      width:
                          (constraints.maxWidth - 16 * (columns - 1)) / columns,
                      child: SensorChart(
                        frames: studio.chart,
                        channel: i,
                        color: [
                          StrideColors.mint,
                          StrideColors.blue,
                          StrideColors.lavender,
                        ][i % 3],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.push('/session/morning'),
            child: const Text('Open sample walk'),
          ),
          const Text(
            'Smart Footwear Telemetry & Sensor Studio.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
          ),
        ],
      );
    },
  );
}

class _SessionControls extends StatelessWidget {
  const _SessionControls({required this.studio});
  final StudioController studio;
  @override
  Widget build(BuildContext context) {
    final seconds = studio.activeMilliseconds ~/ 1000;
    final duration =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Session · ${studio.phase.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Recorded history',
                onPressed: () => context.push('/history'),
                icon: const Icon(Icons.history),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _stat(duration, 'active time'),
              _stat('${studio.detector.steps}', 'detected steps'),
              _stat(studio.cadence?.toStringAsFixed(0) ?? '—', 'steps/min'),
            ],
          ),
          const SizedBox(height: 18),
          if (studio.historyLoading) const LinearProgressIndicator(),
          if (studio.historyError != null) ...[
            Text(studio.historyError!),
            TextButton(
              onPressed: studio.loadHistory,
              child: const Text('Retry history'),
            ),
          ],
          if (studio.phase == SessionPhase.idle)
            FilledButton.icon(
              onPressed: studio.canStart ? studio.startSession : null,
              icon: const Icon(Icons.fiber_manual_record, size: 16),
              label: const Text('Start session'),
            ),
          if (studio.sessionActive)
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: studio.phase == SessionPhase.recording
                      ? studio.pause
                      : studio.connected
                      ? studio.resume
                      : null,
                  child: Text(
                    studio.phase == SessionPhase.recording
                        ? 'Pause session'
                        : 'Resume session',
                  ),
                ),
                OutlinedButton(
                  onPressed: studio.stop,
                  child: const Text('Stop & save'),
                ),
              ],
            ),
          if (studio.phase == SessionPhase.saving)
            const Text('Saving locally…'),
          if (studio.saveError != null) ...[
            Text(
              studio.saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (studio.phase == SessionPhase.unsaved)
              FilledButton(
                onPressed: studio.retrySave,
                child: const Text('Retry save'),
              ),
          ],
          if (studio.lastSaved != null && studio.phase == SessionPhase.idle)
            TextButton(
              onPressed: () => context.push('/session/${studio.lastSaved!.id}'),
              child: const Text('View saved session'),
            ),
          const SizedBox(height: 10),
          const Text(
            'Session summaries stay on this device. Pauses and disconnected time are excluded. The latest 100 recorded sessions are kept.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}
