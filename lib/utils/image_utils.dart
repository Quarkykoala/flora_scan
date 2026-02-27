import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Image processing utilities for EXIF stripping and quality scoring.
class ImageUtils {
  ImageUtils._();

  /// Strip EXIF metadata from image bytes.
  /// Returns clean image bytes without metadata for privacy.
  static Future<Uint8List> stripExifMetadata(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Re-encode without EXIF data
      return Uint8List.fromList(img.encodeJpg(image, quality: 92));
    } catch (e) {
      // If processing fails, return original bytes
      debugPrint('Failed to strip EXIF metadata: $e');
      return imageBytes;
    }
  }

  /// Compute SHA-256 hash of image bytes for deduplication.
  static String computeSha256(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Estimate image quality score (0.0 - 1.0).
  /// Combines blur detection, brightness, and basic framing heuristics.
  static Future<ImageQualityResult> assessQuality(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return const ImageQualityResult(
          overallScore: 0.0,
          blurScore: 0.0,
          brightnessScore: 0.0,
          framingScore: 0.0,
        );
      }

      final blurScore = _estimateBlurScore(image);
      final brightnessScore = _estimateBrightnessScore(image);
      final framingScore = _estimateFramingScore(image);

      // Weighted combination
      final overall =
          blurScore * 0.4 + brightnessScore * 0.3 + framingScore * 0.3;

      return ImageQualityResult(
        overallScore: overall.clamp(0.0, 1.0),
        blurScore: blurScore,
        brightnessScore: brightnessScore,
        framingScore: framingScore,
      );
    } catch (e) {
      debugPrint('Failed to assess image quality: $e');
      return const ImageQualityResult(
        overallScore: 0.5,
        blurScore: 0.5,
        brightnessScore: 0.5,
        framingScore: 0.5,
      );
    }
  }

  /// Simple Laplacian variance-based blur detection.
  static double _estimateBlurScore(img.Image image) {
    // Downsample for speed
    final small = img.copyResize(image, width: 200);
    final grayscale = img.grayscale(small);

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        // Laplacian kernel approximation
        final center = grayscale.getPixel(x, y).luminance * 4;
        final neighbors = grayscale.getPixel(x - 1, y).luminance +
            grayscale.getPixel(x + 1, y).luminance +
            grayscale.getPixel(x, y - 1).luminance +
            grayscale.getPixel(x, y + 1).luminance;

        final laplacian = (center - neighbors).abs();
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0.5;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    // Normalize: higher variance = sharper image
    // Typical range: 0-0.01 for very blurry to 0.05+ for sharp
    return (variance * 20).clamp(0.0, 1.0);
  }

  /// Estimate brightness quality (penalize too dark or too bright).
  static double _estimateBrightnessScore(img.Image image) {
    final small = img.copyResize(image, width: 100);
    double totalLuminance = 0;
    int count = 0;

    for (final pixel in small) {
      totalLuminance += pixel.luminance;
      count++;
    }

    if (count == 0) return 0.5;

    final avgLuminance = totalLuminance / count;

    // Optimal brightness is around 0.4-0.6
    // Score decreases as we move away from optimal range
    if (avgLuminance < 0.15) return avgLuminance / 0.15 * 0.5;
    if (avgLuminance > 0.85) return (1.0 - avgLuminance) / 0.15 * 0.5;
    if (avgLuminance >= 0.3 && avgLuminance <= 0.7) return 1.0;

    // Transition zones
    if (avgLuminance < 0.3) return 0.5 + (avgLuminance - 0.15) / 0.15 * 0.5;
    return 0.5 + (0.85 - avgLuminance) / 0.15 * 0.5;
  }

  /// Estimate framing quality based on subject centering heuristic.
  static double _estimateFramingScore(img.Image image) {
    // Check aspect ratio (prefer portrait or square for plant photos)
    final aspectRatio = image.width / image.height;
    double aspectScore;
    if (aspectRatio >= 0.6 && aspectRatio <= 1.5) {
      aspectScore = 1.0;
    } else {
      aspectScore = 0.6;
    }

    // Check minimum resolution
    final minDim =
        image.width < image.height ? image.width : image.height;
    double resolutionScore;
    if (minDim >= 500) {
      resolutionScore = 1.0;
    } else if (minDim >= 200) {
      resolutionScore = minDim / 500;
    } else {
      resolutionScore = 0.3;
    }

    return (aspectScore * 0.5 + resolutionScore * 0.5).clamp(0.0, 1.0);
  }

  /// Get image dimensions without full decode.
  static Future<ImageDimensions?> getImageDimensions(
      Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;
      return ImageDimensions(width: image.width, height: image.height);
    } catch (e) {
      debugPrint('Failed to get image dimensions: $e');
      return null;
    }
  }

  /// Read image file as bytes.
  static Future<Uint8List> readImageFile(String path) async {
    return File(path).readAsBytes();
  }

  /// Detect MIME type from image bytes using magic numbers.
  /// Falls back to 'application/octet-stream' if unknown.
  static String getMimeType(Uint8List bytes) {
    if (bytes.length < 12) return 'application/octet-stream';

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    // GIF87a or GIF89a
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return 'image/gif';
    }

    // WebP: RIFF .... WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    return 'application/octet-stream';
  }
}

/// Result of image quality assessment.
class ImageQualityResult {
  final double overallScore;
  final double blurScore;
  final double brightnessScore;
  final double framingScore;

  const ImageQualityResult({
    required this.overallScore,
    required this.blurScore,
    required this.brightnessScore,
    required this.framingScore,
  });
}

/// Image dimensions.
class ImageDimensions {
  final int width;
  final int height;

  const ImageDimensions({required this.width, required this.height});
}
