import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/studio_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/csv_export_dialog.dart';
import '../replay/replay_pressure_chart.dart';

class RecordedSessionScreen extends StatelessWidget {
  const RecordedSessionScreen({
    super.key,
    required this.studio,
    required this.id,
  });
  final StudioController studio;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: studio,
    builder: (context, _) {
      final matches = studio.sessions.where((s) => s.id == id);
      final session = matches.isEmpty ? null : matches.first;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Recorded walk'),
          actions: [
            IconButton(
              tooltip: 'Export this recording as CSV',
              onPressed:
                  session == null ||
                      studio.historyLoading ||
                      studio.historyError != null
                  ? null
                  : () => showCsvExport(context, [session]),
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (studio.historyLoading)
                  const LinearProgressIndicator()
                else if (studio.historyError != null)
                  StatePanel(
                    icon: Icons.error_outline,
                    title: 'History unavailable',
                    message: studio.historyError!,
                    action: 'Retry history',
                    onAction: studio.loadHistory,
                  )
                else if (session == null)
                  StatePanel(
                    icon: Icons.search_off,
                    title: 'Session unavailable',
                    message: 'This recording is no longer in local history.',
                    action: 'View history',
                    onAction: () => context.go('/history'),
                  )
                else ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: StatusPill('SIMULATED · LOCAL RECORDING'),
                  ),
                  const SizedBox(height: 20),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${session.steps} steps',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          session.startedAt.toLocal().toString().substring(
                            0,
                            19,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Active time: ${(session.activeMilliseconds / 1000).toStringAsFixed(1)} seconds',
                        ),
                        Text(
                          'Session average: ${session.activeMilliseconds == 0 ? '—' : session.cadence.toStringAsFixed(1)} contacts/min',
                        ),
                        Text(
                          'Recent timing consistency: ${session.consistency?.toStringAsFixed(1) ?? 'insufficient contacts'}',
                        ),
                        Text(
                          'Baseline: ${session.calibrated ? 'calibrated' : 'factory offsets'}',
                        ),
                        const SizedBox(height: 20),
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${['Heel', 'Forefoot', 'Toe'][i]} pressure share: ${session.pressureShares[i].toStringAsFixed(1)}%',
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: session.pressureShares[i] / 100,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Contacts are detected from one simulated insole. Session average = contacts × 60,000 ÷ active milliseconds. Paused time is excluded. Timing consistency uses the latest valid intervals, not the whole session. ADC shares are relative signal totals, not calibrated force.',
                          style: TextStyle(height: 1.5),
                        ),
                        TextButton(
                          onPressed: () => context.push('/gait'),
                          child: const Text('How metrics are calculated'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (session.replay.isNotEmpty) ...[
                    const Text(
                      'Pressure checkpoints · 0–4095 ADC · active time →',
                    ),
                    ReplayPressureChart(
                      points: session.replay,
                      position: session.replay.first.activeMilliseconds,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.push('/replay/${session.id}'),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Walk Replay'),
                    ),
                  ] else
                    const Text(
                      'Replay unavailable: this older session saved a summary only. New recordings include replay checkpoints.',
                    ),
                  const SizedBox(height: 20),
                  if (studio.saveError != null)
                    Text(
                      studio.saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: studio.phase != SessionPhase.idle
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete this recording?'),
                                content: const Text(
                                  'This removes the session and its replay. Trends, achievements and quest progress will be recalculated.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) {
                              return;
                            }
                            final deleted = await studio.deleteSession(id);
                            if (deleted && context.mounted) {
                              context.go('/history');
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete recording'),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}
