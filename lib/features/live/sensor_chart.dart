import 'package:flutter/material.dart';
import '../../domain/sensor.dart';

/// Fixed ranges and clipping keep outliers from distorting the viewport.
class SensorChart extends StatelessWidget {
  const SensorChart({
    super.key,
    required this.frames,
    required this.channel,
    required this.color,
  });
  final List<SensorFrame> frames;
  final int channel;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final value = frames.isEmpty
        ? '—'
        : frames.last.values[channel].toStringAsFixed(channel < 3 ? 0 : 2);
    return Semantics(
      label:
          '${SensorFrame.labels[channel]} simulated chart, latest $value ${SensorFrame.units[channel]}, last six seconds',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${SensorFrame.labels[channel]}  $value ${SensorFrame.units[channel]}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 62,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TracePainter(
                  frames,
                  channel,
                  color,
                  Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          Text(
            channel < 3
                ? '0–4095 ADC'
                : channel < 6
                ? '−2 to 2 g'
                : '−250 to 250 °/s',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.frames, this.channel, this.color, this.grid);
  final List<SensorFrame> frames;
  final int channel;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = .5;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (frames.length < 2) {
      return;
    }
    final max = SensorFrame.limits[channel],
        min = channel < 3 ? 0.0 : -SensorFrame.limits[channel];
    final path = Path();
    for (var i = 0; i < frames.length; i++) {
      final x = size.width * (120 - frames.length + i) / 119;
      final y =
          size.height *
          (1 - (frames[i].values[channel].clamp(min, max) - min) / (max - min));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) => true;
}
