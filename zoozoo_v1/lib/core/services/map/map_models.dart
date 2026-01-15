/// Universal coordinate model
/// Independent of any map package (latlong2, mapbox_gl, etc.)
class AppLatLng {
  final double latitude;
  final double longitude;

  const AppLatLng(this.latitude, this.longitude);

  @override
  String toString() => 'AppLatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Marker data for map
class AppMarker {
  final String id;
  final AppLatLng position;
  final AppMarkerType type;

  const AppMarker({
    required this.id,
    required this.position,
    required this.type,
  });
}

/// Marker types
enum AppMarkerType {
  userLocation,
  destination,
  driver,
}

/// Route line data
class AppRoute {
  final List<AppLatLng> points;
  final bool isDotted;

  const AppRoute({
    required this.points,
    this.isDotted = false,
  });
}
