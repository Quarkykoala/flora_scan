/// Geohash encoding utility for privacy-aware location storage.
class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode latitude/longitude to a geohash string of given precision.
  static String encode(double latitude, double longitude, {int precision = 6}) {
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    bool isLon = true;
    int bit = 0;
    int ch = 0;
    final buffer = StringBuffer();

    while (buffer.length < precision) {
      if (isLon) {
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isLon = !isLon;
      bit++;

      if (bit == 5) {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Round coordinate to ~1km precision for privacy.
  static double roundCoordinate(double value, {int decimals = 2}) {
    final factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  static double _pow10(int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
