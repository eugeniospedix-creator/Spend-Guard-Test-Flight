import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'gps_models.dart';

class GeofenceBridge {
  static const MethodChannel _channel = MethodChannel('spendguard/native_geofence');

  Future<void> requestAlwaysPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await _channel.invokeMethod('requestAlwaysPermission');
  }

  Future<void> startProLocationMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await _channel.invokeMethod('startProLocationMode');
  }

  Future<void> armStoreGeofence(StoreCandidate candidate) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    await _channel.invokeMethod('startMonitoringStore', <String, dynamic>{
      'name': candidate.name,
      'category': candidate.category,
      'lat': candidate.latitude,
      'lng': candidate.longitude,
      'radius': candidate.nativeGeofenceRadiusMeters.clamp(12.0, 25.0),
    });
  }
}
