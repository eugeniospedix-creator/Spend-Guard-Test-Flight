import 'gps_models.dart';

abstract class StoreLookup {
  Future<List<StoreCandidate>> nearbyStores(GpsReading reading);
}

class StoreDetector {
  final StoreLookup lookup;

  const StoreDetector({required this.lookup});

  Future<StoreCandidate?> bestCandidate(GpsReading reading) async {
    final stores = await lookup.nearbyStores(reading);

    if (stores.isEmpty) return null;

    final validStores = stores
        .where((store) => store.distanceMeters <= 35)
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    if (validStores.isEmpty) return null;

    return validStores.first;
  }
}
