import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for Mapbox API calls (Geocoding, Directions)
class MapboxApiService {
  static const String _accessToken =
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjRiMzV5MGV1aDNkb2dzd2J0aGVpNyJ9.khYanFeyddvuxj4ZWqzCyA';

  /// Search for a location and return coordinates [lng, lat]
  /// Returns null if not found or error
  static Future<MapboxGeocodingResult?> getCoordinates(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?access_token=$_accessToken'
        '&limit=1'
        '&language=zh-TW',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;

        if (features != null && features.isNotEmpty) {
          final feature = features[0];
          final coordinates = feature['center'] as List; // [lng, lat]
          final placeName = feature['place_name'] as String?;

          return MapboxGeocodingResult(
            longitude: (coordinates[0] as num).toDouble(),
            latitude: (coordinates[1] as num).toDouble(),
            placeName: placeName ?? query,
          );
        }
      }

      debugPrint('Geocoding failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }

  /// Get driving route between two points
  /// Returns GeoJSON LineString coordinates
  static Future<MapboxRouteResult?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?access_token=$_accessToken'
        '&geometries=geojson'
        '&overview=full',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final duration = (route['duration'] as num?)?.toDouble() ?? 0;
          final distance = (route['distance'] as num?)?.toDouble() ?? 0;

          // Convert to List<List<double>> [lng, lat]
          final routeCoordinates = coordinates
              .map((coord) => [
                    (coord[0] as num).toDouble(),
                    (coord[1] as num).toDouble(),
                  ])
              .toList();

          return MapboxRouteResult(
            coordinates: routeCoordinates,
            durationSeconds: duration,
            distanceMeters: distance,
          );
        }
      }

      debugPrint('Directions failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Directions error: $e');
      return null;
    }
  }
}

/// Result from Mapbox Geocoding API
class MapboxGeocodingResult {
  final double latitude;
  final double longitude;
  final String placeName;

  MapboxGeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.placeName,
  });
}

/// Result from Mapbox Directions API
class MapboxRouteResult {
  final List<List<double>> coordinates; // [[lng, lat], ...]
  final double durationSeconds;
  final double distanceMeters;

  MapboxRouteResult({
    required this.coordinates,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  /// Convert to GeoJSON LineString string
  String toGeoJson() {
    final coordsJson = coordinates
        .map((c) => '[${c[0]}, ${c[1]}]')
        .join(', ');

    return '''
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [$coordsJson]
      }
    }
    ''';
  }
}
