/// Custom map style for milk tea theme
/// 
/// Colors:
/// - Primary: #D4A574 (焦糖奶茶)
/// - Accent: #4A3728 (濃縮咖啡)
/// - Background: #FAF6F1 (奶泡白)
abstract class MapStyle {
  /// Milk tea themed map style URL
  /// Using Mapbox Streets as base with custom colors
  static const String milkTeaStyleUrl = 
      'mapbox://styles/mapbox/light-v11';

  /// Custom style JSON for milk tea theme
  /// This can be used with styleString parameter
  static String get milkTeaStyleJson => '''
{
  "version": 8,
  "name": "Milk Tea",
  "sources": {
    "mapbox": {
      "type": "vector",
      "url": "mapbox://mapbox.mapbox-streets-v8"
    }
  },
  "sprite": "mapbox://sprites/mapbox/light-v11",
  "glyphs": "mapbox://fonts/mapbox/{fontstack}/{range}.pbf",
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#FAF6F1"
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "mapbox",
      "source-layer": "water",
      "paint": {
        "fill-color": "#E8CBAB"
      }
    },
    {
      "id": "landuse-park",
      "type": "fill",
      "source": "mapbox",
      "source-layer": "landuse",
      "filter": ["==", "class", "park"],
      "paint": {
        "fill-color": "#E5DDD3"
      }
    },
    {
      "id": "building",
      "type": "fill",
      "source": "mapbox",
      "source-layer": "building",
      "paint": {
        "fill-color": "#F3EBE1",
        "fill-opacity": 0.8
      }
    },
    {
      "id": "road-primary",
      "type": "line",
      "source": "mapbox",
      "source-layer": "road",
      "filter": ["==", "class", "primary"],
      "paint": {
        "line-color": "#FFFFFF",
        "line-width": 3
      }
    },
    {
      "id": "road-secondary",
      "type": "line",
      "source": "mapbox",
      "source-layer": "road",
      "filter": ["==", "class", "secondary"],
      "paint": {
        "line-color": "#FFFFFF",
        "line-width": 2
      }
    },
    {
      "id": "road-street",
      "type": "line",
      "source": "mapbox",
      "source-layer": "road",
      "filter": ["==", "class", "street"],
      "paint": {
        "line-color": "#FFFFFF",
        "line-width": 1
      }
    },
    {
      "id": "road-label",
      "type": "symbol",
      "source": "mapbox",
      "source-layer": "road",
      "layout": {
        "text-field": ["get", "name"],
        "text-size": 12,
        "text-font": ["DIN Pro Regular", "Arial Unicode MS Regular"]
      },
      "paint": {
        "text-color": "#4A3728"
      }
    },
    {
      "id": "poi-label",
      "type": "symbol",
      "source": "mapbox",
      "source-layer": "poi_label",
      "layout": {
        "text-field": ["get", "name"],
        "text-size": 11,
        "text-font": ["DIN Pro Regular", "Arial Unicode MS Regular"]
      },
      "paint": {
        "text-color": "#6B5344"
      }
    }
  ]
}
''';
}
