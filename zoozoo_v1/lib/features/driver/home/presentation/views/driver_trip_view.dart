import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/driver_bloc.dart';
import '../../data/driver_state.dart';
import '../widgets/driver_top_bar.dart';
import '../widgets/driver_profile_sheet.dart';

class DriverTripView extends StatefulWidget {
  final DriverState state;

  const DriverTripView({
    super.key,
    required this.state,
  });

  @override
  State<DriverTripView> createState() => _DriverTripViewState();
}

class _DriverTripViewState extends State<DriverTripView> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  static const String _accessToken = 'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjU1MTJhMGN5bjNlczc1Y2o2OWpsNCJ9.KG88KmWjysp0PNFO5LCZ1g';

  @override
  void didUpdateWidget(DriverTripView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.status != oldWidget.state.status || 
        widget.state.currentOrder?.id != oldWidget.state.currentOrder?.id) {
      _updateRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.state.currentOrder;
    if (order == null) return const SizedBox.shrink();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Map Layer
          MapWidget(
            styleUri: MapboxStyles.DARK, // Revert to Dark style (Original)
            cameraOptions: CameraOptions(
              zoom: 15.0,
              pitch: 0.0, // Start flat, tilt later in nav mode
            ),
            onMapCreated: (MapboxMap mapboxMap) {
              _mapboxMap = mapboxMap;
              _mapboxMap?.location.updateSettings(
                LocationComponentSettings(
                  enabled: true,
                  pulsingEnabled: true,
                  puckBearingEnabled: true,
                ),
              );
              _centerCameraOnUser(); // Immediate feedback
              _updateRoute();
            },
          ),

          // 2. UI Overlay
          SafeArea(
            child: Column(
              children: [
                DriverTopBar(
                  isOnline: true,
                  onProfileTap: () => _showProfilePage(context),
                ),
                const Spacer(),
                _buildBottomPanel(context, order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, Order order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Status & Passenger
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    order.passenger.avatarEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.state.status.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      widget.state.status == DriverStatus.toPickup
                          ? '前往 ${order.pickupAddress}'
                          : widget.state.status == DriverStatus.arrived
                              ? '等待乘客上車...'
                              : '前往 ${order.destinationAddress}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // Phone Button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.success, size: 20),
                  onPressed: () => _showSnackBar(context, '撥打電話功能開發中'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _handleAction(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _getActionButtonLabel(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionButtonLabel() {
    switch (widget.state.status) {
      case DriverStatus.toPickup:
        return '已到達上車點';
      case DriverStatus.arrived:
        return '乘客已上車';
      case DriverStatus.inTrip:
        return '完成行程';
      default:
        return '處理中';
    }
  }

  void _handleAction(BuildContext context) {
    if (widget.state.status == DriverStatus.toPickup) {
      context.read<DriverBloc>().arrivedAtPickup();
      _showSnackBar(context, '已到達上車點');
    } else if (widget.state.status == DriverStatus.arrived) {
      context.read<DriverBloc>().startTrip();
      _showSnackBar(context, '行程開始');
    } else if (widget.state.status == DriverStatus.inTrip) {
      context.read<DriverBloc>().completeTrip();
    }
  }

  Future<void> _centerCameraOnUser() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      _mapboxMap?.setCamera(CameraOptions(
        center: Point(coordinates: Position(position.longitude, position.latitude)),
        zoom: 15.0,
      ));
    } catch (e) {
      debugPrint("Error centering initial camera: $e");
    }
  }

  StreamSubscription<geo.Position>? _positionStream;

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // --- Map Logic ---

  Future<void> _updateRoute() async {
    if (_mapboxMap == null) return;
    
    final order = widget.state.currentOrder;
    if (order == null) return;

    // Reset annotations
    _pointAnnotationManager ??= await _mapboxMap!.annotations.createPointAnnotationManager();
    _polylineAnnotationManager ??= await _mapboxMap!.annotations.createPolylineAnnotationManager();
    await _pointAnnotationManager?.deleteAll();
    await _polylineAnnotationManager?.deleteAll();

    // Determine target
    Position? targetPos;
    if (widget.state.status == DriverStatus.toPickup) {
      targetPos = Position(order.pickupLocation.longitude, order.pickupLocation.latitude);
    } else if (widget.state.status == DriverStatus.inTrip) {
      targetPos = Position(order.destinationLocation.longitude, order.destinationLocation.latitude);
    }

    if (widget.state.status == DriverStatus.arrived) {
      // Arrived state: Zoom in to pickup, no route
       final p = Position(order.pickupLocation.longitude, order.pickupLocation.latitude);
       await _addMarker(p);
       _mapboxMap?.flyTo(
          CameraOptions(
             center: Point(coordinates: p),
             zoom: 18.0, 
             pitch: 0,
             bearing: 0
          ), 
          MapAnimationOptions(duration: 1000)
       );
       return;
    }

    if (targetPos != null) {
      try {
        final position = await geo.Geolocator.getCurrentPosition();
        final currentPos = Position(position.longitude, position.latitude);

        // Add Target Marker
        await _addMarker(targetPos);

        // Fetch & Draw Route
        final routeGeometry = await _fetchRouteGeometry(currentPos, targetPos);
        
        await _polylineAnnotationManager?.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: routeGeometry),
          lineColor: Colors.white.value, 
          lineWidth: 5.0,
          lineJoin: LineJoin.ROUND,
        ));

        // Start Navigation Mode (Follow User)
        if (routeGeometry.isNotEmpty) {
           // Calculate initial bearing to the first few points of the route
           // simple approx: bearing to target or first point
           final initialBearing = geo.Geolocator.bearingBetween(
             position.latitude, position.longitude, 
             targetPos.lat.toDouble(), targetPos.lng.toDouble()
           );
           
           _startNavigationMode(initialBearing);
        }

      } catch (e) {
        debugPrint('Error updating route: $e');
      }
    }
  }

  void _startNavigationMode(double initialBearing) {
    _positionStream?.cancel();
    
    // Initial Camera Move
    _mapboxMap?.flyTo(
      CameraOptions(
        zoom: 18.0, // Zoom in closer
        pitch: 60.0, // Tilted view
        bearing: initialBearing, // Face the path
        padding: MbxEdgeInsets(top: 0, left: 0, bottom: 200, right: 0), // Shift center down slightly
      ),
      MapAnimationOptions(duration: 2000)
    );

    // Continuous Tracking
    const locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Update every 2 meters
    );
    
    _positionStream = geo.Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((pos) {
         if (!mounted) return;
         
         // Use device heading if moving, otherwise keep current or route bearing
         double? bearing;
         if (pos.speed > 2) {
           bearing = pos.heading;
         }
         
         _mapboxMap?.easeTo(
            CameraOptions(
              center: Point(coordinates: Position(pos.longitude, pos.latitude)),
              zoom: 18.0,
              pitch: 60.0,
              bearing: bearing, // Update bearing if available
              padding: MbxEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
            ),
            MapAnimationOptions(duration: 1000) // smooth update
         );
    });
  }

  // Old fitBounds removed/replaced
  Future<void> _fitBounds(List<Position> points, {bool padding = true}) async { 
    // Kept as helper if needed, but unused in nav mode
  }

  Future<void> _addMarker(Position pos) async {
    final markerImage = await _createMarkerImage(AppColors.accent);
    await _pointAnnotationManager?.create(PointAnnotationOptions(
      geometry: Point(coordinates: pos),
      image: markerImage,
      iconSize: 1.0,
    ));
  }

  Future<List<Position>> _fetchRouteGeometry(Position start, Position end) async {
    try {
      final client = HttpClient();
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/${start.lng},${start.lat};${end.lng},${end.lat}?geometries=geojson&overview=full&access_token=$_accessToken'
      );
      
      final request = await client.getUrl(url);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          return coordinates.map<Position>((coord) => Position(coord[0] as num, coord[1] as num)).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching trip route: $e");
    }
    return [start, end];
  }

  Future<Uint8List> _createMarkerImage(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final radius = 10.0;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
    final picture = recorder.endRecording();
    final img = await picture.toImage((radius * 2).toInt(), (radius * 2).toInt());
    return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _showProfilePage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const DriverProfileSheet(),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
