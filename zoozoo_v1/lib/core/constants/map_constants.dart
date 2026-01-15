/// Map related constants
abstract class MapConstants {
  /// Default center: Taipei 101
  static const double defaultLatitude = 25.0330;
  static const double defaultLongitude = 121.5654;

  /// Default zoom level
  static const double defaultZoom = 14.0;

  /// Min/Max zoom
  static const double minZoom = 10.0;
  static const double maxZoom = 18.0;

  /// Taipei bounds (for limiting map area)
  static const double taipeiNorthLat = 25.2100;
  static const double taipeiSouthLat = 24.9600;
  static const double taipeiEastLng = 121.6700;
  static const double taipeiWestLng = 121.4500;
}
