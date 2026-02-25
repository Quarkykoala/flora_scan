import 'dart:math';
import 'package:flutter/material.dart';

/// Animated radar sweep overlay for the scan screen.
class RadarSweepOverlay extends StatefulWidget {
  final bool isActive;
  final double size;

  const RadarSweepOverlay({
    super.key,
    this.isActive = true,
    this.size = 280,
  });

  @override
  State<RadarSweepOverlay> createState() => _RadarSweepOverlayState();
}

class _RadarSweepOverlayState extends State<RadarSweepOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RadarSweepOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarSweepPainter(
              sweepAngle: _controller.value * 2 * pi,
              color: const Color(0xFF2E7D32),
            ),
          );
        },
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final Color color;

  _RadarSweepPainter({
    required this.sweepAngle,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw concentric circles
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, circlePaint);
    }

    // Draw outer circle
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerPaint);

    // Draw crosshairs
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crossPaint,
    );

    // Draw sweep
    final sweepGradient = SweepGradient(
      startAngle: sweepAngle - 0.8,
      endAngle: sweepAngle,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.3),
      ],
      transform: GradientRotation(sweepAngle - 0.8),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - 0.8,
      0.8,
      true,
      sweepPaint,
    );

    // Draw sweep line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final endX = center.dx + radius * cos(sweepAngle);
    final endY = center.dy + radius * sin(sweepAngle);
    canvas.drawLine(center, Offset(endX, endY), linePaint);

    // Center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(_RadarSweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}
