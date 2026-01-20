import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../theme/app_colors.dart';
import 'map_models.dart';

/// Manager for map annotations and models
///
/// Currently uses 2D point annotations (emoji markers).
/// Can be extended for 3D models (.glb/.gltf) when available.
///
/// Usage:
/// ```dart
/// final manager = MapModelManager(mapboxMap);
/// await manager.initialize();
/// await manager.updateDriverMarker(location, heading: 45.0);
/// await manager.updatePassengerMarker(location);
/// await manager.updateDestinationMarker(location);
/// ```
class MapModelManager {
  final MapboxMap _mapboxMap;
  PointAnnotationManager? _annotationManager;

  // Track individual marker annotations for updates
  PointAnnotation? _driverAnnotation;
  PointAnnotation? _passengerAnnotation;
  PointAnnotation? _destinationAnnotation;

  MapModelManager(this._mapboxMap);

  /// Initialize the annotation manager
  Future<void> initialize() async {
    _annotationManager = await _mapboxMap.annotations.createPointAnnotationManager();
  }

  /// Update driver marker position and heading
  ///
  /// [location] - Driver's current position
  /// [heading] - Driver's heading in degrees (0-360, 0 = North)
  Future<void> updateDriverMarker(AppLatLng location, {double? heading}) async {
    if (_annotationManager == null) return;

    // Remove existing driver marker
    if (_driverAnnotation != null) {
      await _annotationManager!.delete(_driverAnnotation!);
    }

    // Create new driver marker
    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(location.longitude, location.latitude),
      ),
      textField: '🚗',
      textSize: 28,
      textRotate: heading ?? 0,
      textOffset: [0, 0],
    );

    _driverAnnotation = await _annotationManager!.create(options);
  }

  /// Update passenger pickup marker
  Future<void> updatePassengerMarker(AppLatLng? location) async {
    if (_annotationManager == null) return;

    // Remove existing marker
    if (_passengerAnnotation != null) {
      await _annotationManager!.delete(_passengerAnnotation!);
      _passengerAnnotation = null;
    }

    if (location == null) return;

    // Create new marker
    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(location.longitude, location.latitude),
      ),
      textField: '📍',
      textSize: 28,
      textOffset: [0, 0],
    );

    _passengerAnnotation = await _annotationManager!.create(options);
  }

  /// Update destination marker
  Future<void> updateDestinationMarker(AppLatLng? location) async {
    if (_annotationManager == null) return;

    // Remove existing marker
    if (_destinationAnnotation != null) {
      await _annotationManager!.delete(_destinationAnnotation!);
      _destinationAnnotation = null;
    }

    if (location == null) return;

    // Create new marker
    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(location.longitude, location.latitude),
      ),
      textField: '🏁',
      textSize: 28,
      textOffset: [0, 0],
    );

    _destinationAnnotation = await _annotationManager!.create(options);
  }

  /// Clear all markers
  Future<void> clearAll() async {
    if (_annotationManager == null) return;
    await _annotationManager!.deleteAll();
    _driverAnnotation = null;
    _passengerAnnotation = null;
    _destinationAnnotation = null;
  }

  /// Dispose resources
  void dispose() {
    _annotationManager = null;
    _driverAnnotation = null;
    _passengerAnnotation = null;
    _destinationAnnotation = null;
  }
}

/// Route manager for polyline annotations
class MapRouteManager {
  final MapboxMap _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PolylineAnnotation? _routeAnnotation;

  MapRouteManager(this._mapboxMap);

  /// Initialize the polyline manager
  Future<void> initialize() async {
    _polylineManager = await _mapboxMap.annotations.createPolylineAnnotationManager();
  }

  /// Update the route polyline
  Future<void> updateRoute(AppRoute? route) async {
    if (_polylineManager == null) return;

    // Clear existing route
    if (_routeAnnotation != null) {
      await _polylineManager!.delete(_routeAnnotation!);
      _routeAnnotation = null;
    }

    if (route == null || route.points.isEmpty) return;

    // Create new route
    final coordinates = route.points
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: coordinates),
      lineColor: AppColors.primary.toARGB32(),
      lineWidth: 5.0,
    );

    _routeAnnotation = await _polylineManager!.create(options);
  }

  /// Clear the route
  Future<void> clearRoute() async {
    if (_polylineManager == null) return;
    await _polylineManager!.deleteAll();
    _routeAnnotation = null;
  }

  /// Dispose resources
  void dispose() {
    _polylineManager = null;
    _routeAnnotation = null;
  }
}
