import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../theme/app_colors.dart';
import 'map_models.dart';
import 'map_service.dart';

/// Mapbox implementation with 2D default view
///
/// Features:
/// - 2D map by default (Pitch 0)
/// - Supports markers and polylines
/// - Optional 3D toggle available
class MapboxMapService implements MapService {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  AppLatLng? _currentCenter;
  List<AppMarker> _pendingMarkers = [];
  AppRoute? _pendingRoute;

  /// Mapbox public access token
  static const String _accessToken =
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjRiMzV5MGV1aDNkb2dzd2J0aGVpNyJ9.khYanFeyddvuxj4ZWqzCyA';

  @override
  Widget buildMap({
    required AppLatLng initialCenter,
    required double initialZoom,
    required Function(AppLatLng) onTap,
    List<AppMarker> markers = const [],
    AppRoute? route,
  }) {
    _currentCenter = initialCenter;
    _pendingMarkers = markers;
    _pendingRoute = route;

    return MapWidget(
      key: const ValueKey('mapbox_map_2d'),
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            initialCenter.longitude,
            initialCenter.latitude,
          ),
        ),
        zoom: initialZoom,
        pitch: 0.0, // 2D view by default
        bearing: 0.0,
      ),
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: (mapboxMap) async {
        _mapboxMap = mapboxMap;

        // Set access token
        MapboxOptions.setAccessToken(_accessToken);

        // Create annotation managers
        _circleAnnotationManager =
            await mapboxMap.annotations.createCircleAnnotationManager();
        _polylineAnnotationManager =
            await mapboxMap.annotations.createPolylineAnnotationManager();

        // Add pending markers and route
        await _updateMarkers(_pendingMarkers);
        if (_pendingRoute != null) {
          await _updateRoute(_pendingRoute!);
        }
      },
      onTapListener: (context) {
        final coordinates = context.point.coordinates;
        onTap(AppLatLng(
          coordinates.lat.toDouble(),
          coordinates.lng.toDouble(),
        ));
      },
      onCameraChangeListener: (cameraChangedEventData) {
        _mapboxMap?.getCameraState().then((state) {
          final center = state.center.coordinates;
          _currentCenter = AppLatLng(
            center.lat.toDouble(),
            center.lng.toDouble(),
          );
        });
      },
    );
  }

  /// Update markers on the map
  Future<void> _updateMarkers(List<AppMarker> markers) async {
    if (_circleAnnotationManager == null) return;

    await _circleAnnotationManager!.deleteAll();

    for (final marker in markers) {
      final color = _getMarkerColor(marker.type);
      final options = CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            marker.position.longitude,
            marker.position.latitude,
          ),
        ),
        circleColor: color.toARGB32(),
        circleRadius: 10.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.0,
      );

      await _circleAnnotationManager!.create(options);
    }
  }

  Color _getMarkerColor(AppMarkerType type) {
    switch (type) {
      case AppMarkerType.userLocation:
        return Colors.green;
      case AppMarkerType.destination:
        return Colors.red;
      case AppMarkerType.driver:
        return Colors.blue;
    }
  }

  /// Update route polyline
  Future<void> _updateRoute(AppRoute route) async {
    if (_polylineAnnotationManager == null) return;

    await _polylineAnnotationManager!.deleteAll();

    if (route.points.isEmpty) return;

    final coordinates =
        route.points.map((p) => Position(p.longitude, p.latitude)).toList();

    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: coordinates),
      lineColor: AppColors.primary.toARGB32(),
      lineWidth: 4.0,
    );

    await _polylineAnnotationManager!.create(options);
  }

  @override
  void moveTo(AppLatLng location, {double? zoom}) {
    if (_mapboxMap == null) return;

    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(location.longitude, location.latitude),
        ),
        zoom: zoom,
        pitch: 0.0, // Keep 2D view
      ),
      MapAnimationOptions(duration: 300),
    );

    _currentCenter = location;
  }

  @override
  AppLatLng? getCurrentCenter() {
    return _currentCenter;
  }

  @override
  void dispose() {
    _circleAnnotationManager = null;
    _polylineAnnotationManager = null;
    _mapboxMap = null;
  }

  /// Update markers dynamically
  Future<void> updateMarkers(List<AppMarker> markers) async {
    _pendingMarkers = markers;
    await _updateMarkers(markers);
  }

  /// Update route dynamically
  Future<void> updateRoute(AppRoute? route) async {
    _pendingRoute = route;
    if (route != null) {
      await _updateRoute(route);
    } else if (_polylineAnnotationManager != null) {
      await _polylineAnnotationManager!.deleteAll();
    }
  }
}
