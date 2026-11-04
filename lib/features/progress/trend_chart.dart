import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/progress.dart';
import '../../widgets/components.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.window,
    required this.metric,
    required this.onSelect,
    this.selected,
  });
  final TrendWindow window;
  final TrendMetric metric;
  final ValueChanged<int> onSelect;
  final int? selected;
  @override
  Widget build(BuildContext context) {
    double value(TrendBucket bucket) => metric == TrendMetric.steps
        ? bucket.totals.steps.toDouble()
        : bucket.totals.minutes;
    final maxValue = math.max(1.0, window.buckets.map(value).reduce(math.max));
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric == TrendMetric.steps
                ? 'Recorded contacts'
                : 'Active recording minutes',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Text(
            '0–${maxValue.toStringAsFixed(metric == TrendMetric.steps ? 0 : 1)} · tap a bar to filter history',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(window.buckets.length, (i) {
                final bucket = window.buckets[i], amount = value(bucket);
                final label =
                    '${shortDate(bucket.start)}–${shortDate(DateTime(bucket.end.year, bucket.end.month, bucket.end.day - 1))}';
                return Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        '$label: ${amount.toStringAsFixed(metric == TrendMetric.steps ? 0 : 1)} ${metric == TrendMetric.steps ? 'contacts' : 'minutes'}, ${bucket.totals.sessions} recordings',
                    child: InkWell(
                      onTap: () => onSelect(i),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              amount.toStringAsFixed(
                                metric == TrendMetric.steps ? 0 : 1,
                              ),
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: math.max(2, amount / maxValue * 115),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(
                                          alpha: selected == i ? 1 : .45,
                                        ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              bucket.label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Zero means no saved recording activity in that bucket, not no real-world movement.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}
