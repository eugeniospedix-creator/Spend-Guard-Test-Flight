import 'gps_models.dart';

abstract class StoreLookup {
  Future<List<StoreCandidate>> nearbyStores(GpsReading reading);
}

class StoreDetector {
  final StoreLookup lookup;

  static String lastDebug = 'StoreDetector not checked yet';

  const StoreDetector({required this.lookup});

  Future<StoreCandidate?> bestCandidate(GpsReading reading) async {
    final stores = await lookup.nearbyStores(reading);

    if (stores.isEmpty) {
      lastDebug = 'StoreDetector Build 34\nReturned stores: 0\nChosen: NONE';
      return null;
    }

    final rows = <String>[];
    final validStores = <StoreCandidate>[];

    for (final store in stores) {
      final accepted = store.distanceMeters <= 55;
      rows.add(
        '${accepted ? "✅" : "❌"} ${store.name} • ${store.category} • ${store.distanceMeters.toStringAsFixed(0)}m'
        '${accepted ? "" : " • rejected: distance >55m"}',
      );
      if (accepted) validStores.add(store);
    }

    validStores.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    lastDebug = [
      'StoreDetector Build 34',
      'GPS accuracy: ${reading.accuracyMeters.toStringAsFixed(0)}m',
      'Returned stores: ${stores.length}',
      ...rows.take(12),
      validStores.isEmpty ? 'Chosen: NONE' : 'Chosen: ${validStores.first.name}',
    ].join('\n');

    if (validStores.isEmpty) return null;
    return validStores.first;
  }
}
