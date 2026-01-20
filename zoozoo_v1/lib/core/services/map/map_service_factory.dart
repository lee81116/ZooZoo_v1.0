import 'map_service.dart';
import 'osm_map_service.dart';
import 'mapbox_map_service.dart';

/// Factory for creating map services
class MapServiceFactory {
  /// Current active provider
  /// Change this to switch map providers globally
  static MapProvider currentProvider = MapProvider.mapbox;

  /// Create a map service instance
  static MapService create({MapProvider? provider}) {
    final targetProvider = provider ?? currentProvider;
    
    switch (targetProvider) {
      case MapProvider.openStreetMap:
        return OsmMapService();
      case MapProvider.mapbox:
        return MapboxMapService();
    }
  }
}
