import 'dart:math' as math;

import 'gps_models.dart';

class MovementDetector {
  static const int maxPoints = 12;

  final List<GpsReading> _points = [];

  void add(GpsReading reading) {
    _points.add(reading);
    if (_points.length > maxPoints) {
      _points.removeAt(0);
    }
  }

  void clear() => _points.clear();

  List<GpsReading> get points => List.unmodifiable(_points);

  MovementState currentState() {
    if (_points.isEmpty) return MovementState.unknown;

    final latest = _points.last;

    if (latest.accuracyMeters > 30) {
      return MovementState.gpsUnreliable;
    }

    if (latest.speedMps > 3.0) {
      return MovementState.driving;
    }

    if (latest.speedMps > 1.2) {
      return MovementState.walking;
    }

    if (_points.length >= 4 && spreadMeters() <= 12) {
      return MovementState.stationary;
    }

    return MovementState.unknown;
  }

  bool get isStableAndStationary => currentState() == MovementState.stationary;

  double spreadMeters() {
    if (_points.length < 2) return 999;

    final anchor = _points.last;
    var spread = 0.0;

    for (final point in _points) {
      final distance = _distanceMeters(
        anchor.latitude,
        anchor.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance > spread) spread = distance;
    }

    return spread;
  }

  double dwellSeconds() {
    if (_points.length < 2) return 0;

    final first = _points.first.timestamp;
    final last = _points.last.timestamp;

    final seconds = last.difference(first).inSeconds;
    return seconds < 0 ? 0 : seconds.toDouble();
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;

    double toRad(double degrees) => degrees * math.pi / 180.0;

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
