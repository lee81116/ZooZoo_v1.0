import 'package:flutter/material.dart';

import '../../../../../core/constants/map_constants.dart';
import '../../../../../core/services/map/map.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/glass_button.dart';
import '../widgets/destination_search_bar.dart';
import '../widgets/saved_places_list.dart';
import '../widgets/vehicle_selection_sheet.dart';

/// Booking map page - main page for ride booking
/// Uses MapService abstraction for easy provider switching
class BookingMapPage extends StatefulWidget {
  const BookingMapPage({super.key});

  @override
  State<BookingMapPage> createState() => _BookingMapPageState();
}

class _BookingMapPageState extends State<BookingMapPage> {
  late final MapService _mapService;
  
  final AppLatLng _userLocation = const AppLatLng(
    MapConstants.defaultLatitude,
    MapConstants.defaultLongitude,
  );
  AppLatLng? _destinationLocation;
  String? _destinationName;
  bool _showDestinationSearch = true;

  @override
  void initState() {
    super.initState();
    // Create map service from factory (easily switchable)
    _mapService = MapServiceFactory.create();
  }

  @override
  void dispose() {
    _mapService.dispose();
    super.dispose();
  }

  void _onMapTap(AppLatLng location) {
    if (_showDestinationSearch) {
      _onDestinationSelected(location, '地圖選擇的位置');
    }
  }

  void _onDestinationSelected(AppLatLng location, String name) {
    setState(() {
      _destinationLocation = location;
      _destinationName = name;
      _showDestinationSearch = false;
    });

    // Move camera to destination
    _mapService.moveTo(location, zoom: 15.0);

    // Show vehicle selection after short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _showVehicleSelection();
    });
  }

  void _showVehicleSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VehicleSelectionSheet(
        destination: _destinationName ?? '目的地',
        onConfirm: (vehicleType, price) {
          Navigator.pop(context);
          _goToCheckout(vehicleType, price);
        },
      ),
    );
  }

  void _goToCheckout(String vehicleType, int price) {
    // Navigate to checkout page (placeholder)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('前往結帳'),
        content: Text('車型: $vehicleType\n價格: \$$price\n\n結帳頁面開發中'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _onBackPressed() {
    if (!_showDestinationSearch && _destinationLocation != null) {
      // Reset to destination search
      setState(() {
        _showDestinationSearch = true;
        _destinationLocation = null;
        _destinationName = null;
      });
      // Reset camera to user location
      _mapService.moveTo(_userLocation, zoom: MapConstants.defaultZoom);
    } else {
      Navigator.pop(context);
    }
  }

  /// Build markers list
  List<AppMarker> _buildMarkers() {
    final markers = <AppMarker>[
      AppMarker(
        id: 'user',
        position: _userLocation,
        type: AppMarkerType.userLocation,
      ),
    ];

    if (_destinationLocation != null) {
      markers.add(AppMarker(
        id: 'destination',
        position: _destinationLocation!,
        type: AppMarkerType.destination,
      ));
    }

    return markers;
  }

  /// Build route if destination selected
  AppRoute? _buildRoute() {
    if (_destinationLocation == null) return null;
    
    return AppRoute(
      points: [_userLocation, _destinationLocation!],
      isDotted: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map (using abstraction layer)
          _mapService.buildMap(
            initialCenter: _userLocation,
            initialZoom: MapConstants.defaultZoom,
            onTap: _onMapTap,
            markers: _buildMarkers(),
            route: _buildRoute(),
          ),
          
          // Top bar with back button
          _buildTopBar(),
          
          // Bottom panel
          if (_showDestinationSearch) _buildDestinationPanel(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back,
                onPressed: _onBackPressed,
                iconColor: AppColors.accent,
              ),
              const Spacer(),
              GlassIconButton(
                icon: Icons.my_location,
                onPressed: () {
                  _mapService.moveTo(_userLocation, zoom: MapConstants.defaultZoom);
                },
                iconColor: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '你要去哪裡？',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DestinationSearchBar(
                onPlaceSelected: (latLng, name) {
                  _onDestinationSelected(latLng, name);
                },
              ),
            ),
            const SizedBox(height: 24),
            // Saved places
            SavedPlacesList(
              onPlaceSelected: (latLng, name) {
                _onDestinationSelected(latLng, name);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
