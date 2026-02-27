import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/utils/image_utils.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ImageUtils', () {
    late Uint8List validImageBytes;
    late Uint8List invalidImageBytes;

    setUp(() {
      // Create a simple valid JPEG image
      final image = img.Image(width: 100, height: 100);
      validImageBytes = Uint8List.fromList(img.encodeJpg(image));

      // Create invalid random bytes
      invalidImageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    });

    test('stripExifMetadata returns original bytes on failure', () async {
      // Test with invalid bytes to trigger exception catch block
      final result = await ImageUtils.stripExifMetadata(invalidImageBytes);
      expect(result, equals(invalidImageBytes));
    });

    test('stripExifMetadata processes valid image', () async {
      final result = await ImageUtils.stripExifMetadata(validImageBytes);
      expect(result, isNotNull);
      expect(result.isNotEmpty, true);
    });

    test('assessQuality returns default scores on failure', () async {
      final result = await ImageUtils.assessQuality(invalidImageBytes);
      expect(result.overallScore, equals(0.5));
      expect(result.blurScore, equals(0.5));
      expect(result.brightnessScore, equals(0.5));
      expect(result.framingScore, equals(0.5));
    });

    test('assessQuality processes valid image', () async {
      final result = await ImageUtils.assessQuality(validImageBytes);
      expect(result.overallScore, inInclusiveRange(0.0, 1.0));
      expect(result.blurScore, inInclusiveRange(0.0, 1.0));
    });

    test('getImageDimensions returns null on failure', () async {
      final result = await ImageUtils.getImageDimensions(invalidImageBytes);
      expect(result, isNull);
    });

    test('getImageDimensions returns correct dimensions for valid image', () async {
      final result = await ImageUtils.getImageDimensions(validImageBytes);
      expect(result, isNotNull);
      expect(result!.width, equals(100));
      expect(result.height, equals(100));
    });
  });
}
