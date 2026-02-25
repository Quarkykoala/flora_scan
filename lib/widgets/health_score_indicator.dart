import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Circular health score indicator with gradient coloring.
class HealthScoreIndicator extends StatelessWidget {
  final int? score;
  final double size;

  const HealthScoreIndicator({
    super.key,
    required this.score,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final displayScore = score ?? 0;
    final progress = displayScore / 100.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                Colors.grey.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(_getColor(displayScore)),
            ),
          ),
          // Score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score != null ? '$displayScore' : '--',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: score != null
                      ? _getColor(displayScore)
                      : Colors.grey,
                ),
              ),
              Text(
                'Health',
                style: TextStyle(
                  fontSize: size * 0.12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColor(int score) {
    if (score >= 80) return AppTheme.confidenceHigh;
    if (score >= 60) return const Color(0xFF8BC34A);
    if (score >= 40) return AppTheme.confidenceMedium;
    if (score >= 20) return AppTheme.warningAmber;
    return AppTheme.confidenceLow;
  }
}
