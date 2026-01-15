import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng2;

import '../../theme/app_colors.dart';
import '../../../core/constants/map_constants.dart';
import 'map_models.dart';
import 'map_service.dart';

/// OpenStreetMap implementation using flutter_map
class OsmMapService implements MapService {
  final MapController _mapController = MapController();

  @override
  Widget buildMap({
    required AppLatLng initialCenter,
    required double initialZoom,
    required Function(AppLatLng) onTap,
    List<AppMarker> markers = const [],
    AppRoute? route,
  }) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _toLatLng2(initialCenter),
        initialZoom: initialZoom,
        minZoom: MapConstants.minZoom,
        maxZoom: MapConstants.maxZoom,
        onTap: (tapPosition, latLng) {
          onTap(_fromLatLng2(latLng));
        },
      ),
      children: [
        // Tile layer with milk tea color filter
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zoozoo.app',
          tileBuilder: _milkTeaTileBuilder,
        ),
        // Route line
        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.points.map(_toLatLng2).toList(),
                color: AppColors.primary,
                strokeWidth: 4,
                isDotted: route.isDotted,
              ),
            ],
          ),
        // Markers layer
        MarkerLayer(
          markers: markers.map(_buildMarker).toList(),
        ),
      ],
    );
  }

  @override
  void moveTo(AppLatLng location, {double? zoom}) {
    _mapController.move(
      _toLatLng2(location),
      zoom ?? _mapController.camera.zoom,
    );
  }

  @override
  AppLatLng? getCurrentCenter() {
    final center = _mapController.camera.center;
    return _fromLatLng2(center);
  }

  @override
  void dispose() {
    _mapController.dispose();
  }

  // ===== Private helpers =====

  /// Convert AppLatLng to latlong2.LatLng
  latlng2.LatLng _toLatLng2(AppLatLng loc) {
    return latlng2.LatLng(loc.latitude, loc.longitude);
  }

  /// Convert latlong2.LatLng to AppLatLng
  AppLatLng _fromLatLng2(latlng2.LatLng loc) {
    return AppLatLng(loc.latitude, loc.longitude);
  }

  /// Apply milk tea color filter to map tiles
  /// Currently disabled - using original map style
  Widget _milkTeaTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    // 暫時不套用濾鏡，使用原始地圖樣式
    return tileWidget;
  }

  /// Build a marker widget
  Marker _buildMarker(AppMarker marker) {
    return Marker(
      point: _toLatLng2(marker.position),
      width: 40,
      height: 40,
      child: _buildMarkerWidget(marker.type),
    );
  }

  Widget _buildMarkerWidget(AppMarkerType type) {
    switch (type) {
      case AppMarkerType.userLocation:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 20,
          ),
        );
      case AppMarkerType.destination:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.flag,
            color: Colors.white,
            size: 20,
          ),
        );
      case AppMarkerType.driver:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_taxi,
            color: Colors.white,
            size: 20,
          ),
        );
    }
  }
}
