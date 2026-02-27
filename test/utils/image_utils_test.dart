import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flora_scan/utils/image_utils.dart';

void main() {
  group('ImageUtils', () {
    // Helper to create a solid color image
    Uint8List createSolidImage(int width, int height, int r, int g, int b) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(r, g, b));
      return Uint8List.fromList(img.encodeJpg(image));
    }

    // Helper to create a noise image
    Uint8List createNoiseImage(int width, int height) {
      final image = img.Image(width: width, height: height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          image.setPixelRgb(x, y, (x * y) % 255, (x + y) % 255, (x - y).abs() % 255);
        }
      }
      return Uint8List.fromList(img.encodeJpg(image));
    }

    test('assessQuality returns default scores for empty/invalid bytes', () async {
      // Empty bytes
      final resultEmpty = await ImageUtils.assessQuality(Uint8List(0));
      // When decode fails (or throws), it returns 0.5s
      expect(resultEmpty.overallScore, 0.5);

      // Invalid bytes
      final resultInvalid = await ImageUtils.assessQuality(Uint8List.fromList([1, 2, 3]));
      expect(resultInvalid.overallScore, 0.5);
    });

    test('assessQuality scores solid black image (0 luminance)', () async {
      // Black image:
      // Blur: 0 (no variance) -> 0.0
      // Brightness: 0 luminance. 0 < 0.15. Score = 0/0.15*0.5 = 0.0.
      // Framing: 500x500 is square (aspect 1.0) -> aspectScore 1.0. MinDim 500 -> resScore 1.0. Framing -> 1.0
      // Overall: 0*0.4 + 0*0.3 + 1.0*0.3 = 0.3.

      final bytes = createSolidImage(500, 500, 0, 0, 0);
      final result = await ImageUtils.assessQuality(bytes);

      expect(result.blurScore, 0.0);
      expect(result.brightnessScore, 0.0);
      expect(result.framingScore, 1.0);
      expect(result.overallScore, closeTo(0.3, 0.001));
    });

    test('assessQuality scores solid mid-gray image (128 luminance)', () async {
      // Gray image (128, 128, 128)
      // Brightness: avgLuminance = 128 (assuming 0-255 range).
      // 128 > 0.85 -> (1.0 - 128) / 0.15 * 0.5 = -127 / 0.15 * 0.5 = -423.33.
      // NOTE: This behavior seems unintended (likely expected 0.0-1.0 range), but we characterize it as is.

      final bytes = createSolidImage(500, 500, 128, 128, 128);
      final result = await ImageUtils.assessQuality(bytes);

      expect(result.brightnessScore, closeTo(-423.33, 0.1));
      expect(result.framingScore, 1.0);

      // Overall: 0*0.4 + (-423.33)*0.3 + 1.0*0.3 = -127 + 0.3 = -126.7.
      // Clamped to 0.0.
      expect(result.overallScore, 0.0);
    });

     test('assessQuality scores noise image (high variance)', () async {
      final bytes = createNoiseImage(500, 500);
      final result = await ImageUtils.assessQuality(bytes);

      // Noise should have high variance.
      // If luminance is 0-255, variance is large.
      // variance * 20 -> Huge. Clamped to 1.0.
      expect(result.blurScore, 1.0);
    });
  });
}
