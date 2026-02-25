import 'package:flutter/services.dart';

/// Haptic feedback patterns as specified in the PRD.
class AppHaptics {
  AppHaptics._();

  /// Heavy impact: Scan button press.
  static Future<void> scanButtonPress() async {
    await HapticFeedback.heavyImpact();
  }

  /// Subtle tick: Upload accepted.
  static Future<void> uploadAccepted() async {
    await HapticFeedback.lightImpact();
  }

  /// Double success: Diagnosis result received.
  static Future<void> diagnosisReceived() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Warning pattern: Incomplete telemetry / low-confidence result.
  static Future<void> warningPattern() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Selection feedback.
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
}
