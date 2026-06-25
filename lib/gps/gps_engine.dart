import 'package:geolocator/geolocator.dart';

import 'geofence_bridge.dart';
import 'gps_confidence.dart';
import 'gps_models.dart';
import 'movement_detector.dart';
import 'store_detector.dart';

class GpsEngine {
  final MovementDetector movementDetector;
  final StoreDetector storeDetector;
  final GpsConfidenceEngine confidenceEngine;
  final GeofenceBridge geofenceBridge;

  StoreCandidate? _armedCandidate;
  DateTime? _lastArmAt;

  GpsEngine({
    required this.movementDetector,
    required this.storeDetector,
    required this.confidenceEngine,
    required this.geofenceBridge,
  });

  StoreCandidate? get armedCandidate => _armedCandidate;

  Future<GpsEngineDecision> evaluatePosition(Position position) async {
    final reading = GpsReading.fromPosition(position);
    movementDetector.add(reading);

    final movement = movementDetector.currentState();

    if (movement == MovementState.gpsUnreliable) {
      return GpsEngineDecision(
        state: GeofenceArmState.blocked,
        movement: movement,
        debugMessage:
            'GPS blocked • accuracy ${reading.accuracyMeters.toStringAsFixed(0)}m is too weak',
      );
    }

    if (movement == MovementState.driving) {
      return GpsEngineDecision(
        state: GeofenceArmState.blocked,
        movement: movement,
        debugMessage:
            'Driving detected • ${reading.speedKmh.toStringAsFixed(0)} km/h • ignoring shops',
      );
    }

    if (movement != MovementState.stationary) {
      return GpsEngineDecision(
        state: GeofenceArmState.evaluating,
        movement: movement,
        debugMessage:
            'GPS settling • ${movementDetector.points.length}/4 points • spread ${movementDetector.spreadMeters().toStringAsFixed(0)}m • dwell ${movementDetector.dwellSeconds().toStringAsFixed(0)}s',
      );
    }

    final candidate = await storeDetector.bestCandidate(reading);

    if (candidate == null) {
      return GpsEngineDecision(
        state: GeofenceArmState.idle,
        movement: movement,
        debugMessage:
            'No reliable store candidate • spread ${movementDetector.spreadMeters().toStringAsFixed(0)}m',
      );
    }

    final confidence = confidenceEngine.evaluate(
      reading: reading,
      movement: movementDetector,
      candidate: candidate,
    );

    if (!confidence.shouldArmGeofence) {
      return GpsEngineDecision(
        state: GeofenceArmState.candidateFound,
        movement: movement,
        candidate: candidate,
        confidence: confidence,
        debugMessage:
            'Candidate ${candidate.name} not armed yet • ${confidence.debugText}',
      );
    }

    if (_shouldSkipDuplicateArm(candidate)) {
      return GpsEngineDecision(
        state: GeofenceArmState.armed,
        movement: movement,
        candidate: candidate,
        confidence: confidence,
        debugMessage:
            'Native geofence already armed • ${candidate.name} • ${confidence.debugText}',
      );
    }

    await geofenceBridge.armStoreGeofence(candidate);
    _armedCandidate = candidate;
    _lastArmAt = DateTime.now();

    return GpsEngineDecision(
      state: GeofenceArmState.armed,
      movement: movement,
      candidate: candidate,
      confidence: confidence,
      debugMessage:
          'Native geofence armed • ${candidate.name} • ${confidence.debugText}',
    );
  }

  bool _shouldSkipDuplicateArm(StoreCandidate candidate) {
    final current = _armedCandidate;
    final last = _lastArmAt;

    if (current == null || last == null) return false;
    if (current.name != candidate.name) return false;

    return DateTime.now().difference(last) < const Duration(minutes: 5);
  }

  void reset() {
    movementDetector.clear();
    _armedCandidate = null;
    _lastArmAt = null;
  }
}
