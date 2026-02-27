import 'dart:typed_data';

import 'package:flora_scan/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ImageUtils', () {
    late Uint8List validImageBytes;
    late Uint8List invalidImageBytes;

    setUp(() {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(120, 120, 120));
      validImageBytes = Uint8List.fromList(img.encodeJpg(image));
      invalidImageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    });

    test('stripExifMetadata returns original bytes on decode failure', () async {
      final result = await ImageUtils.stripExifMetadata(invalidImageBytes);
      expect(result, equals(invalidImageBytes));
    });

    test('stripExifMetadata processes valid image', () async {
      final result = await ImageUtils.stripExifMetadata(validImageBytes);
      expect(result, isNotEmpty);
    });

    test('assessQuality returns safe scores for invalid image', () async {
      final result = await ImageUtils.assessQuality(invalidImageBytes);
      expect(result.overallScore, inInclusiveRange(0.0, 0.5));
      expect(result.blurScore, inInclusiveRange(0.0, 0.5));
      expect(result.brightnessScore, inInclusiveRange(0.0, 0.5));
      expect(result.framingScore, inInclusiveRange(0.0, 0.5));
    });

    test('assessQuality returns bounded scores for valid image', () async {
      final result = await ImageUtils.assessQuality(validImageBytes);
      expect(result.overallScore, inInclusiveRange(0.0, 1.0));
      expect(result.blurScore, inInclusiveRange(0.0, 1.0));
      expect(result.framingScore, inInclusiveRange(0.0, 1.0));
    });

    test('getImageDimensions returns null for invalid bytes', () async {
      final result = await ImageUtils.getImageDimensions(invalidImageBytes);
      expect(result, isNull);
    });

    test('getImageDimensions returns dimensions for valid image', () async {
      final result = await ImageUtils.getImageDimensions(validImageBytes);
      expect(result, isNotNull);
      expect(result!.width, equals(100));
      expect(result.height, equals(100));
    });
  });
}
