import 'dart:math';
import 'package:flutter/material.dart';

import '../config/theme.dart';

enum AmbientMood { sunny, rainy, night, calm }

/// A slowly animating gradient background that simulates ambient light/mood.
class AmbientBackground extends StatefulWidget {
  final Widget? child;
  final AmbientMood mood;

  const AmbientBackground({
    super.key,
    this.child,
    this.mood = AmbientMood.calm,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getColorsForMood(AmbientMood mood) {
    switch (mood) {
      case AmbientMood.sunny:
        return [
          const Color(0xFFE8F5E9), // Light Green
          const Color(0xFFFFFDE7), // Light Yellow
          const Color(0xFFB2DFDB), // Light Teal
        ];
      case AmbientMood.rainy:
        return [
          const Color(0xFFCFD8DC), // Blue Grey
          const Color(0xFFECEFF1), // Light Grey
          const Color(0xFFB0BEC5), // Slate
        ];
      case AmbientMood.night:
        return [
          const Color(0xFF1A237E), // Deep Blue
          const Color(0xFF311B92), // Deep Purple
          const Color(0xFF004D40), // Deep Teal
        ];
      case AmbientMood.calm:
      default:
        return [
          AppTheme.surfaceLight,
          const Color(0xFFE0F2F1), // Very Light Teal
          const Color(0xFFF1F8E9), // Very Light Green
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColorsForMood(widget.mood);

    return Stack(
      children: [
        // Base gradient layer
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                  stops: [
                    0.0,
                    0.5 + (_controller.value * 0.2), // Animate stop slightly
                    1.0,
                  ],
                  transform: GradientRotation(_controller.value * pi / 12), // Subtle rotation
                ),
              ),
            );
          },
        ),

        // Optional: Mesh/Noise overlay for texture (if needed later)

        // Content
        if (widget.child != null) SafeArea(child: widget.child!),
      ],
    );
  }
}
