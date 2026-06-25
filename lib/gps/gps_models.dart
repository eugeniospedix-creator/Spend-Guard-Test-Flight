import 'package:geolocator/geolocator.dart';

enum MovementState {
  unknown,
  stationary,
  walking,
  driving,
  gpsUnreliable,
}

enum GeofenceArmState {
  idle,
  evaluating,
  candidateFound,
  armed,
  blocked,
}

class GpsReading {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedMps;
  final DateTime timestamp;

  const GpsReading({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedMps,
    required this.timestamp,
  });

  factory GpsReading.fromPosition(Position position) {
    final speed = position.speed.isFinite ? position.speed : 0.0;
    return GpsReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMps: speed < 0 ? 0 : speed,
      timestamp: position.timestamp,
    );
  }

  double get speedKmh => speedMps * 3.6;
}

class StoreCandidate {
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final int risk;
  final double nativeGeofenceRadiusMeters;

  const StoreCandidate({
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.risk = 45,
    this.nativeGeofenceRadiusMeters = 15.0,
  });
}

class ConfidenceResult {
  final int score;
  final bool shouldArmGeofence;
  final List<String> reasons;

  const ConfidenceResult({
    required this.score,
    required this.shouldArmGeofence,
    required this.reasons,
  });

  String get debugText => 'score $score/100 • ${reasons.join(' • ')}';
}

class GpsEngineDecision {
  final GeofenceArmState state;
  final StoreCandidate? candidate;
  final ConfidenceResult? confidence;
  final MovementState movement;
  final String debugMessage;

  const GpsEngineDecision({
    required this.state,
    required this.movement,
    required this.debugMessage,
    this.candidate,
    this.confidence,
  });
}


class GpsEngineResult {
  final GpsEngineDecision decision;
  final bool shouldSaveVisit;
  final bool shouldShowStoreInUi;
  final bool shouldUseNativeNotificationsOnly;

  const GpsEngineResult({
    required this.decision,
    this.shouldSaveVisit = false,
    this.shouldShowStoreInUi = false,
    this.shouldUseNativeNotificationsOnly = true,
  });

  StoreCandidate? get candidate => decision.candidate;
  ConfidenceResult? get confidence => decision.confidence;
  String get debugMessage => decision.debugMessage;
}
