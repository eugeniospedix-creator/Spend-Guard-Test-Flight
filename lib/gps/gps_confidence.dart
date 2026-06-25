import 'gps_models.dart';
import 'movement_detector.dart';

class GpsConfidenceEngine {
  static const int armThreshold = 90;

  ConfidenceResult evaluate({
    required GpsReading reading,
    required MovementDetector movement,
    required StoreCandidate candidate,
  }) {
    var score = 0;
    final reasons = <String>[];

    final accuracyScore = _accuracyScore(reading.accuracyMeters);
    score += accuracyScore;
    reasons.add('accuracy +$accuracyScore (${reading.accuracyMeters.toStringAsFixed(0)}m)');

    final speedScore = _speedScore(reading.speedMps);
    score += speedScore;
    reasons.add('speed +$speedScore (${reading.speedKmh.toStringAsFixed(0)} km/h)');

    final stabilityScore = _stabilityScore(movement.spreadMeters());
    score += stabilityScore;
    reasons.add('stability +$stabilityScore (${movement.spreadMeters().toStringAsFixed(0)}m spread)');

    final dwellScore = _dwellScore(movement.dwellSeconds());
    score += dwellScore;
    reasons.add('dwell +$dwellScore (${movement.dwellSeconds().toStringAsFixed(0)}s)');

    final distanceScore = _distanceScore(candidate.distanceMeters);
    score += distanceScore;
    reasons.add('distance +$distanceScore (${candidate.distanceMeters.toStringAsFixed(0)}m)');

    return ConfidenceResult(
      score: score,
      shouldArmGeofence: score >= armThreshold,
      reasons: reasons,
    );
  }

  int _accuracyScore(double accuracyMeters) {
    if (accuracyMeters <= 10) return 25;
    if (accuracyMeters <= 15) return 22;
    if (accuracyMeters <= 20) return 18;
    if (accuracyMeters <= 25) return 10;
    return 0;
  }

  int _speedScore(double speedMps) {
    if (speedMps <= 0.6) return 20;
    if (speedMps <= 1.2) return 14;
    if (speedMps <= 2.0) return 6;
    return 0;
  }

  int _stabilityScore(double spreadMeters) {
    if (spreadMeters <= 6) return 20;
    if (spreadMeters <= 10) return 16;
    if (spreadMeters <= 12) return 12;
    if (spreadMeters <= 18) return 5;
    return 0;
  }

  int _dwellScore(double dwellSeconds) {
    if (dwellSeconds >= 20) return 20;
    if (dwellSeconds >= 15) return 15;
    if (dwellSeconds >= 10) return 8;
    return 0;
  }

  int _distanceScore(double distanceMeters) {
    if (distanceMeters <= 8) return 15;
    if (distanceMeters <= 12) return 12;
    if (distanceMeters <= 15) return 8;
    return 0;
  }
}
