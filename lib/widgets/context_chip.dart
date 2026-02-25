import 'package:flutter/material.dart';

/// Context chip for displaying telemetry data points
/// (e.g., "Low Light", "High Humidity", "AQI High").
class ContextChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final bool isWarning;

  const ContextChip({
    super.key,
    required this.label,
    required this.icon,
    this.color,
    this.isWarning = false,
  });

  factory ContextChip.temperature(double? tempC) {
    if (tempC == null) {
      return const ContextChip(
        label: 'Temp N/A',
        icon: Icons.thermostat,
      );
    }
    return ContextChip(
      label: '${tempC.toStringAsFixed(1)}°C',
      icon: Icons.thermostat,
      isWarning: tempC > 35 || tempC < 5,
    );
  }

  factory ContextChip.humidity(double? humidity) {
    if (humidity == null) {
      return const ContextChip(
        label: 'Humidity N/A',
        icon: Icons.water_drop,
      );
    }
    final label = humidity > 80
        ? 'High Humidity'
        : humidity < 30
            ? 'Low Humidity'
            : '${humidity.toInt()}% RH';
    return ContextChip(
      label: label,
      icon: Icons.water_drop,
      isWarning: humidity > 80 || humidity < 30,
    );
  }

  factory ContextChip.lux(double? lux, String? source) {
    if (lux == null || source == 'unavailable') {
      return const ContextChip(
        label: 'Light N/A',
        icon: Icons.light_mode,
      );
    }
    final label = lux > 10000
        ? 'Bright Light'
        : lux < 500
            ? 'Low Light'
            : '${lux.toInt()} lux';
    return ContextChip(
      label: label,
      icon: Icons.light_mode,
      isWarning: lux < 500,
    );
  }

  factory ContextChip.aqi(int? aqi) {
    if (aqi == null) {
      return const ContextChip(
        label: 'AQI N/A',
        icon: Icons.air,
      );
    }
    final label = aqi > 100
        ? 'AQI High'
        : aqi > 50
            ? 'AQI Moderate'
            : 'AQI Good';
    return ContextChip(
      label: label,
      icon: Icons.air,
      isWarning: aqi > 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = color ??
        (isWarning ? Colors.orange.shade700 : Colors.blueGrey.shade600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
