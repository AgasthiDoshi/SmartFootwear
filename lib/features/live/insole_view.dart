import 'package:flutter/material.dart';
import '../../domain/sensor.dart';
import '../../core/theme.dart';

class InsoleView extends StatelessWidget {
  const InsoleView({super.key, required this.frame});
  final SensorFrame? frame;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 280,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 130,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(65),
              topRight: Radius.circular(42),
              bottomLeft: Radius.circular(42),
              bottomRight: Radius.circular(42),
            ),
          ),
          child: Column(
            children: [
              _zone(context, 2, StrideColors.lavender, 48),
              const SizedBox(height: 10),
              _zone(context, 1, StrideColors.blue, 74),
              const Spacer(),
              _zone(context, 0, StrideColors.mint, 62),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in [2, 1, 0])
                Text(
                  '${SensorFrame.labels[i]}\n${frame == null ? '—' : frame!.values[i].toStringAsFixed(0)} ADC',
                  style: const TextStyle(height: 1.6),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _zone(BuildContext context, int i, Color color, double height) {
    final pressure = ((frame?.values[i] ?? 0) / 2500).clamp(0.0, 1.0);
    return Semantics(
      label:
          '${SensorFrame.labels[i]} simulated pressure ${(pressure * 100).round()} percent of display scale',
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 90),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color.lerp(
            Theme.of(context).colorScheme.surfaceContainerHighest,
            color,
            .15 + pressure * .85,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withValues(alpha: .5)),
        ),
        child: Icon(
          Icons.circle,
          size: 10 + pressure * 12,
          color: const Color(0xFF151923),
        ),
      ),
    );
  }
}
