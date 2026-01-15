import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'map_models.dart';
import 'map_service.dart';

/// Mapbox implementation (placeholder for future)
/// 
/// To enable:
/// 1. Add mapbox_gl to pubspec.yaml (need compatible version)
/// 2. Implement the actual Mapbox integration
/// 3. Set your Mapbox access token
class MapboxMapService implements MapService {
  // TODO: Add MapboxMapController when implementing
  // MapboxMapController? _mapController;
  
  static const String _accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

  @override
  Widget buildMap({
    required AppLatLng initialCenter,
    required double initialZoom,
    required Function(AppLatLng) onTap,
    List<AppMarker> markers = const [],
    AppRoute? route,
  }) {
    // Placeholder until Mapbox is properly integrated
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Mapbox 整合中',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '請先使用 OpenStreetMap',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    // TODO: Actual Mapbox implementation
    // return MapboxMap(
    //   accessToken: _accessToken,
    //   initialCameraPosition: CameraPosition(
    //     target: LatLng(initialCenter.latitude, initialCenter.longitude),
    //     zoom: initialZoom,
    //   ),
    //   styleString: 'mapbox://styles/...', // Custom milk tea style
    //   onMapCreated: (controller) {
    //     _mapController = controller;
    //   },
    //   onMapClick: (point, latLng) {
    //     onTap(AppLatLng(latLng.latitude, latLng.longitude));
    //   },
    // );
  }

  @override
  void moveTo(AppLatLng location, {double? zoom}) {
    // TODO: Implement with MapboxMapController
    // _mapController?.animateCamera(
    //   CameraUpdate.newLatLngZoom(
    //     LatLng(location.latitude, location.longitude),
    //     zoom ?? 14.0,
    //   ),
    // );
  }

  @override
  AppLatLng? getCurrentCenter() {
    // TODO: Implement with MapboxMapController
    return null;
  }

  @override
  void dispose() {
    // TODO: Dispose MapboxMapController if needed
  }
}
