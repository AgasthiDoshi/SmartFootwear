import 'package:flutter/material.dart';
import '../../domain/coach/coach_models.dart';
import '../../domain/coach/coach_analytics.dart';
import '../../services/coach_controller.dart';
import '../../widgets/components.dart';

class CoachSummaryCards extends StatelessWidget {
  const CoachSummaryCards({
    super.key,
    required this.controller,
    required this.onAsk,
  });
  final CoachController controller;
  final ValueChanged<CoachSuggestion> onAsk;
  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot(),
        data = CoachAnalytics(controller.snapshot());
    if (snapshot.historyState != CoachDataState.ready) {
      return const SizedBox.shrink();
    }
    Widget card(
      CoachPeriod period,
      CoachSuggestion suggestion,
      String heading,
    ) => Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            period.sessions.isEmpty
                ? 'No saved recordings'
                : '${period.steps} contacts',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            period.sessions.isEmpty
                ? 'Real-world activity is unknown.'
                : '${period.minutes.toStringAsFixed(2)} active min · ${period.sessions.length} recordings',
            style: const TextStyle(fontSize: 12),
          ),
          TextButton(
            onPressed: controller.busy ? null : () => onAsk(suggestion),
            child: const Text('Read summary →'),
          ),
        ],
      ),
    );
    final baseline = data.baseline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final width = wide
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: card(
                    data.daily,
                    CoachSuggestion.all[0],
                    'Today · ${dateLabel(data.today)}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: card(
                    data.weekly,
                    CoachSuggestion.all[1],
                    'Week to date · Monday onward',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERSONAL RECORDING BASELINE',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                baseline.sufficient
                    ? '${baseline.cadence!.toStringAsFixed(1)} contacts/min'
                    : 'Building a recording baseline',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                baseline.sufficient
                    ? '${baseline.prior.length} prior moving recordings across ${baseline.dates} local dates. Latest walk excluded.'
                    : 'Needs a latest moving recording plus 3 earlier moving recordings across 2 dates within 28 calendar days. No population norm is substituted.',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () => onAsk(CoachSuggestion.all[3]),
                child: const Text('Explain my baseline →'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
