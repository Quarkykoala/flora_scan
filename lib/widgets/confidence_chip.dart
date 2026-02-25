import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/scan.dart';

/// Displays confidence level as a colored chip.
class ConfidenceChip extends StatelessWidget {
  final ConfidenceLevel level;
  final double? score;

  const ConfidenceChip({
    super.key,
    required this.level,
    this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getColor().withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 14,
            color: _getColor(),
          ),
          const SizedBox(width: 4),
          Text(
            score != null
                ? '${level.displayLabel} (${(score! * 100).toInt()}%)'
                : level.displayLabel,
            style: TextStyle(
              color: _getColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (level) {
      case ConfidenceLevel.high:
        return AppTheme.confidenceHigh;
      case ConfidenceLevel.medium:
        return AppTheme.confidenceMedium;
      case ConfidenceLevel.low:
        return AppTheme.confidenceLow;
    }
  }

  IconData _getIcon() {
    switch (level) {
      case ConfidenceLevel.high:
        return Icons.verified;
      case ConfidenceLevel.medium:
        return Icons.info_outline;
      case ConfidenceLevel.low:
        return Icons.warning_amber;
    }
  }
}
