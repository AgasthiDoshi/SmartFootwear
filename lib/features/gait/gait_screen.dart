import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/studio_controller.dart';
import '../../widgets/components.dart';

class GaitScreen extends StatelessWidget {
  const GaitScreen({super.key, required this.studio});
  final StudioController studio;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: studio,
    builder: (context, _) {
      final hasSamples = studio.gait.samples > 0;
      final shares = studio.gait.shares;
      final consistency = studio.detector.consistency;
      return Scaffold(
        appBar: AppBar(title: const Text('Gait Intelligence')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill('SIMULATED · ONE INSOLE'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Understand your stride.',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  studio.sessionActive
                      ? 'Current session · ${studio.phase.name}'
                      : 'Latest in-memory session. Start a session to collect fresh insights.',
                ),
                const SizedBox(height: 24),
                if (!hasSamples)
                  StatePanel(
                    icon: Icons.insights,
                    title: 'A few steps reveal a rhythm',
                    message:
                        'Record a simulated walk to calculate cadence, contact timing consistency and zone pressure shares.',
                    action: 'Open Sensor Studio',
                    onAction: () => context.go('/live'),
                  ),
                if (hasSamples) ...[
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${studio.detector.steps} detected contacts',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Recent cadence: ${studio.cadence?.toStringAsFixed(1) ?? '—'} steps/min',
                        ),
                        Text(
                          'Timing consistency: ${consistency?.toStringAsFixed(1) ?? '—'} / 100',
                        ),
                        if (consistency == null)
                          const Text(
                            'Needs at least four recent contacts without a pause.',
                          ),
                        const SizedBox(height: 18),
                        const Text(
                          'Cumulative zone pressure share',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${['Heel', 'Forefoot', 'Toe'][i]} · ${shares[i].toStringAsFixed(1)}%',
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(value: shares[i] / 100),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How these insights work',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Contact detection\nA rising sum of the three FSR zones above 700 ADC counts marks one contact. It must fall below 150 to re-arm, with a 300 ms minimum gap. This demo treats one contact cycle as one step; it is not a validated bilateral step counter.\n\nCadence\n60,000 ÷ mean of the latest eight valid contact intervals in milliseconds. Gaps over two seconds clear timing history; cadence becomes unavailable after two seconds without a contact. A pause breaks timing continuity.\n\nTiming consistency\n100 × (1 − standard deviation ÷ mean contact interval), clamped to 0–100. At least three intervals are needed. This reflects recent timing regularity, not a clinical gait score.\n\nPressure share\nEach zone’s accumulated ADC counts ÷ total across all three zones × 100, over active recording samples. Raw ADC counts are not calibrated force. Calibration removes resting sensor offsets. No bilateral symmetry, balance diagnosis, or medical conclusion is inferred.',
                        style: TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/history'),
                  child: const Text('View saved session insights'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'DEMO · For movement awareness only.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
