import 'package:flutter/material.dart';
import '../../domain/replay.dart';
import '../../core/theme.dart';

class ReplayPressureChart extends StatelessWidget {
  const ReplayPressureChart({
    super.key,
    required this.points,
    required this.position,
  });
  final List<ReplayPoint> points;
  final int position;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Saved pressure checkpoint chart, 0 to 4095 ADC counts. Horizontal axis is active recording time.',
    child: SizedBox(
      height: 130,
      width: double.infinity,
      child: CustomPaint(
        painter: _PressurePainter(
          points,
          position,
          Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    ),
  );
}

class _PressurePainter extends CustomPainter {
  _PressurePainter(this.points, this.position, this.grid);
  final List<ReplayPoint> points;
  final int position;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    final span =
        (points.last.activeMilliseconds - points.first.activeMilliseconds)
            .clamp(1, 1 << 53);
    double x(int ms) =>
        size.width * (ms - points.first.activeMilliseconds) / span;
    final line = Paint()
      ..color = grid
      ..strokeWidth = .5;
    for (var i = 0; i <= 2; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 2),
        Offset(size.width, size.height * i / 2),
        line,
      );
    }
    for (var channel = 0; channel < 3; channel++) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final y =
            size.height * (1 - points[i].values[channel].clamp(0, 4095) / 4095);
        if (i == 0) {
          path.moveTo(x(points[i].activeMilliseconds), y);
        } else {
          path.lineTo(x(points[i].activeMilliseconds), y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            StrideColors.mint,
            StrideColors.blue,
            StrideColors.lavender,
          ][channel]
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawLine(
      Offset(x(position), 0),
      Offset(x(position), size.height),
      Paint()
        ..color = grid
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PressurePainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.points != points ||
      oldDelegate.grid != grid;
}
