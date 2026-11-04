import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/progress.dart';
import '../../domain/session_repository.dart';
import '../../services/studio_controller.dart';
import '../../services/progress_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/csv_export_dialog.dart';
import '../progress/trend_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.studio,
    required this.progress,
  });
  final StudioController studio;
  final ProgressController progress;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  TrendPeriod period = TrendPeriod.daily;
  TrendMetric metric = TrendMetric.steps;
  late DateTime anchor = localDay(widget.progress.clock());
  int? selected;
  void shift(int direction) => setState(() {
    anchor = period == TrendPeriod.monthly
        ? DateTime(anchor.year, anchor.month + direction * 6, 1)
        : DateTime(
            anchor.year,
            anchor.month,
            anchor.day + direction * (period == TrendPeriod.daily ? 7 : 56),
          );
    selected = null;
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.studio, widget.progress]),
    builder: (context, _) {
      final studio = widget.studio;
      final sessions = studio.sessions;
      final window = TrendWindow(sessions, period, anchor);
      final bucket = selected == null ? null : window.buckets[selected!];
      final visible =
          sessions
              .where(
                (s) =>
                    bucket == null ||
                    (!s.startedAt.toLocal().isBefore(bucket.start) &&
                        s.startedAt.toLocal().isBefore(bucket.end)),
              )
              .toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return Scaffold(
        appBar: AppBar(
          title: const Text('Progress & history'),
          actions: [
            IconButton(
              tooltip: 'Export all saved recordings as CSV',
              onPressed:
                  studio.historyLoading ||
                      studio.historyError != null ||
                      sessions.isEmpty
                  ? null
                  : () => showCsvExport(context, sessions),
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill('SAVED SIMULATED RECORDINGS'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your progress, in perspective.',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/goals'),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Goals & achievements'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/quests'),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Quest Mode'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                else if (sessions.isEmpty)
                  StatePanel(
                    icon: Icons.route,
                    title: 'Your first recording starts here',
                    message:
                        'Record and save a simulated walk to build your history. No example data is counted toward trends, goals or quests.',
                    action: 'Start a demo walk',
                    onAction: () => context.go('/live'),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    children: TrendPeriod.values
                        .map(
                          (p) => ChoiceChip(
                            label: Text(switch (p) {
                              TrendPeriod.daily => 'Daily',
                              TrendPeriod.weekly => 'Weekly',
                              TrendPeriod.monthly => 'Monthly',
                            }),
                            selected: p == period,
                            onSelected: (_) => setState(() {
                              period = p;
                              selected = null;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous period',
                        onPressed: () => shift(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${shortDate(window.start)}/${window.start.year} – ${shortDate(DateTime(window.end.year, window.end.month, window.end.day - 1))}/${DateTime(window.end.year, window.end.month, window.end.day - 1).year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next period',
                        onPressed: window.end.isAfter(widget.progress.clock())
                            ? null
                            : () => shift(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      anchor = localDay(widget.progress.clock());
                      selected = null;
                    }),
                    child: const Text('Back to current period'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: TrendMetric.values
                        .map(
                          (m) => ChoiceChip(
                            label: Text(
                              m == TrendMetric.steps
                                  ? 'Contacts'
                                  : 'Active minutes',
                            ),
                            selected: m == metric,
                            onSelected: (_) => setState(() => metric = m),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  TrendChart(
                    window: window,
                    metric: metric,
                    selected: selected,
                    onSelect: (i) =>
                        setState(() => selected = selected == i ? null : i),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${window.totals.steps} contacts · ${window.totals.minutes.toStringAsFixed(1)} active min · ${window.totals.sessions} recordings in this window',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Weighted cadence: ${window.totals.cadence?.toStringAsFixed(1) ?? '—'} contacts/min',
                  ),
                  const SizedBox(height: 22),
                  SectionHeading(
                    bucket == null
                        ? 'Recorded on this device'
                        : 'Selected bucket',
                    action: bucket == null ? null : 'Show all',
                    onTap: () => setState(() => selected = null),
                  ),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No saved recordings in this bucket.'),
                    ),
                  ...visible.map((s) => _SessionTile(session: s)),
                  const SizedBox(height: 22),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What the trends mean',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Daily = 7 calendar days; weekly = 8 Monday-based weeks; monthly = 6 calendar months. Sessions are assigned wholly to their local start date; a walk crossing midnight is not split. Each bar sums saved contacts or active milliseconds ÷ 60,000. Weighted cadence = total contacts × 60,000 ÷ total active milliseconds, never an average of session averages.\n\nOnly the latest 100 retained recordings count. Missing recordings are not evidence of inactivity. Deleting sessions changes trends, achievements and quest progress. No distance, calories or route is inferred.',
                          style: TextStyle(fontSize: 12, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final RecordedSession session;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.directions_walk),
    title: Text(
      '${session.steps} steps · ${(session.activeMilliseconds / 1000).toStringAsFixed(1)} s',
    ),
    subtitle: Text(
      '${session.startedAt.toLocal().toString().substring(0, 16)} · SIMULATED',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/session/${session.id}'),
  );
}
