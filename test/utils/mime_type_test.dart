import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/utils/image_utils.dart';

void main() {
  group('ImageUtils.getMimeType', () {
    test('detects JPEG', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01
      ]);
      expect(ImageUtils.getMimeType(bytes), equals('image/jpeg'));
    });

    test('detects PNG', () {
      final bytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D
      ]);
      expect(ImageUtils.getMimeType(bytes), equals('image/png'));
    });

    test('detects GIF87a', () {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x37, 0x61, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
      ]);
      expect(ImageUtils.getMimeType(bytes), equals('image/gif'));
    });

    test('detects GIF89a', () {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
      ]);
      expect(ImageUtils.getMimeType(bytes), equals('image/gif'));
    });

    test('detects WebP', () {
      final bytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // Size (ignored)
        0x57, 0x45, 0x42, 0x50  // WEBP
      ]);
      expect(ImageUtils.getMimeType(bytes), equals('image/webp'));
    });

    test('falls back to octet-stream for unknown bytes', () {
      final bytes = Uint8List.fromList([
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B
      ]);
      expect(ImageUtils.getMimeType(bytes), equals('application/octet-stream'));
    });

    test('falls back to octet-stream for empty/short bytes', () {
      expect(ImageUtils.getMimeType(Uint8List(0)), equals('application/octet-stream'));
      expect(ImageUtils.getMimeType(Uint8List(5)), equals('application/octet-stream'));
    });
  });
}
