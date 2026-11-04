import 'package:flutter/material.dart';
import '../../widgets/components.dart';

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, this.currentSteps});
  final int? currentSteps;
  static const defaultValues = [4200, 5800, 7100, 5300, 8200, 7600, 6420];
  static const days = ['T', 'F', 'S', 'S', 'M', 'T', 'W'];

  @override
  Widget build(BuildContext context) {
    final values = List<int>.from(defaultValues);
    if (currentSteps != null) {
      values[6] = currentSteps!;
    }
    final totalSteps = values.reduce((a, b) => a + b);
    final maxVal = values.reduce((a, b) => a > b ? a : b).clamp(8200, 100000);

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${totalSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
          ),
          Text(
            currentSteps != null ? 'Live 7-day movement · Realtime' : '15–21 Oct · daily steps · DEMO',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (i) => Expanded(
                  child: Semantics(
                    label: 'Day ${i + 1}: ${values[i]} steps',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: (values[i] / maxVal * 96).clamp(4.0, 96.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(alpha: i == 6 ? 1 : .25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(days[i], style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
