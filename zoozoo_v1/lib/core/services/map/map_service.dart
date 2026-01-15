import 'package:flutter/material.dart';

import 'map_models.dart';

/// Abstract map service interface
/// 
/// Implementations:
/// - OsmMapService (OpenStreetMap via flutter_map)
/// - MapboxMapService (Mapbox GL - future)
abstract class MapService {
  /// Build the map widget
  Widget buildMap({
    required AppLatLng initialCenter,
    required double initialZoom,
    required Function(AppLatLng) onTap,
    List<AppMarker> markers = const [],
    AppRoute? route,
  });

  /// Move camera to location
  void moveTo(AppLatLng location, {double? zoom});

  /// Get current camera position
  AppLatLng? getCurrentCenter();

  /// Dispose resources
  void dispose();
}

/// Map service provider type
enum MapProvider {
  openStreetMap,
  mapbox,
}
