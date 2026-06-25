import 'package:geolocator/geolocator.dart';

import '../main.dart' show RealStoreService;
import 'gps_models.dart';
import 'store_detector.dart';

class LegacyStoreLookup implements StoreLookup {
  @override
  Future<List<StoreCandidate>> nearbyStores(GpsReading reading) async {
    final position = Position(
      longitude: reading.longitude,
      latitude: reading.latitude,
      timestamp: reading.timestamp,
      accuracy: reading.accuracyMeters,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: reading.speedMps,
      speedAccuracy: 0,
    );

    final store = await RealStoreService.detectNearestStore(
      position,
      searchRadiusMeters: 80,
    );

    if (store == null) return const [];

    return [
      StoreCandidate(
        name: store.name,
        category: store.category,
        latitude: store.lat,
        longitude: store.lng,
        distanceMeters: store.distanceMeters,
        nativeGeofenceRadiusMeters: 15,
      ),
    ];
  }
}
