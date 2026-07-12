// lib/widgets/trend_sparkline.dart
import 'package:flutter/material.dart';

class TrendSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const TrendSparkline({
    super.key,
    required this.values,
    this.color = Colors.blue,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _SparkPainter(values: values, color: color),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparkPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1.0 : max - min;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - (values[i] - min) / range);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values;
}
