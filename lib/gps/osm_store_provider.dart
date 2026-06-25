import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class OsmStoreCandidate {
  const OsmStoreCandidate({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
  });

  final String name;
  final String category;
  final double lat;
  final double lng;
  final double distanceMeters;
}

class OsmStoreProvider {
  static String lastDebug = 'OSM not checked yet';

  static Future<OsmStoreCandidate?> detectNearestStore(
    Position position, {
    int radiusMeters = 75,
  }) async {
    final radius = radiusMeters.clamp(35, 85);
    final lat = position.latitude;
    final lng = position.longitude;

    final query = '''
[out:json][timeout:8];
(
  node["shop"](around:$radius,$lat,$lng);
  way["shop"](around:$radius,$lat,$lng);
  relation["shop"](around:$radius,$lat,$lng);

  node["amenity"~"cafe|restaurant|fast_food|pharmacy|fuel"](around:$radius,$lat,$lng);
  way["amenity"~"cafe|restaurant|fast_food|pharmacy|fuel"](around:$radius,$lat,$lng);
  relation["amenity"~"cafe|restaurant|fast_food|pharmacy|fuel"](around:$radius,$lat,$lng);
);
out center tags;
''';

    try {
      final uri = Uri.https('overpass-api.de', '/api/interpreter');
      final response = await http
          .post(uri, body: {'data': query})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        lastDebug = 'OSM HTTP ${response.statusCode}';
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements =
          ((decoded['elements'] as List?) ?? []).whereType<Map<String, dynamic>>().toList();

      if (elements.isEmpty) {
        lastDebug = 'No OSM shops within ${radius}m';
        return null;
      }

      OsmStoreCandidate? best;
      double bestScore = double.infinity;
      var considered = 0;

      for (final element in elements) {
        final rawTags = element['tags'];
        final tags = rawTags is Map
            ? rawTags.map((k, v) => MapEntry(k.toString(), v.toString()))
            : <String, String>{};

        final name = (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? '').trim();
        if (name.isEmpty) continue;

        final shop = (tags['shop'] ?? '').toLowerCase();
        final amenity = (tags['amenity'] ?? '').toLowerCase();

        final isShop = shop.isNotEmpty;
        final isSpendAmenity =
            {'cafe', 'restaurant', 'fast_food', 'pharmacy', 'fuel'}.contains(amenity);

        if (!isShop && !isSpendAmenity && !_looksLikeKnownShop(name)) continue;

        final center = element['center'];
        final latRaw = element['lat'] ?? (center is Map ? center['lat'] : null);
        final lngRaw = element['lon'] ?? (center is Map ? center['lon'] : null);
        if (latRaw is! num || lngRaw is! num) continue;

        final storeLat = latRaw.toDouble();
        final storeLng = lngRaw.toDouble();

        final distance = Geolocator.distanceBetween(lat, lng, storeLat, storeLng);
        if (distance > radius) continue;

        considered++;

        var score = distance;
        if (_looksLikeKnownShop(name)) score -= 45;
        if (shop == 'supermarket' || shop == 'convenience' || shop == 'mall') score -= 25;
        if (shop == 'clothes' || shop == 'electronics' || shop == 'department_store') score -= 18;
        if (amenity == 'fuel') score -= 12;
        if (amenity == 'pharmacy') score -= 8;

        final category = _categoryFromOsm(shop: shop, amenity: amenity, name: name);

        if (score < bestScore) {
          bestScore = score;
          best = OsmStoreCandidate(
            name: name,
            category: category,
            lat: storeLat,
            lng: storeLng,
            distanceMeters: distance,
          );
        }
      }

      if (best == null) {
        lastDebug = 'No OSM shop inside rules • ${elements.length} ignored';
        return null;
      }

      lastDebug =
          'OSM ok • ${elements.length} results • $considered shops • best ${best.name} ${best.distanceMeters.toStringAsFixed(0)}m';

      return best;
    } catch (e) {
      lastDebug = 'OSM failed: $e';
      return null;
    }
  }

  static String _categoryFromOsm({
    required String shop,
    required String amenity,
    required String name,
  }) {
    final n = name.toLowerCase();

    if (amenity == 'fuel' || n.contains('circle k') || n.contains('maxol')) {
      return 'fuel';
    }

    if (amenity == 'pharmacy' || shop == 'chemist' || n.contains('pharmacy')) {
      return 'pharmacy';
    }

    if (shop == 'supermarket' || shop == 'convenience' || n.contains('spar') || n.contains('tesco')) {
      return 'grocery';
    }

    if (shop == 'clothes' || n.contains('zara') || n.contains('penneys') || n.contains('primark')) {
      return 'fashion';
    }

    if (shop == 'electronics' || n.contains('currys') || n.contains('apple')) {
      return 'electronics';
    }

    if (amenity == 'cafe' || amenity == 'restaurant' || amenity == 'fast_food') {
      return 'food';
    }

    return 'store';
  }

  static bool _looksLikeKnownShop(String name) {
    final n = name.toLowerCase();
    const brands = [
      'ikea', 'tesco', 'lidl', 'aldi', 'spar', 'mace', 'centra', 'supervalu', 'dunnes',
      'maxol', 'circle k', 'apple', 'currys', 'boots', 'penneys', 'primark', 'zara',
      'hm', 'h&m', 'tk maxx', 'starbucks', 'costa', 'mcdonald', 'burger king', 'subway',
      'decathlon', 'woodies', 'b&q', 'next', 'marks', 'm&s', 'dealz', 'eurogiant',
      'harvey norman', 'jysk', 'argos', 'homebase', 'dfs', 'pharmacy', 'chemist'
    ];
    return brands.any(n.contains);
  }
}
