import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import '../../../../../core/models/order_model.dart'; // Import Order Model
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/driver_bloc.dart';
import '../../data/driver_state.dart';
import '../widgets/driver_profile_sheet.dart';

class DriverWaitingView extends StatefulWidget {
  final DriverState state;

  const DriverWaitingView({
    super.key,
    required this.state,
  });

  // Mapbox Access Token (should ideally be in a config file)
  static const String _accessToken =
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjU1MTJhMGN5bjNlczc1Y2o2OWpsNCJ9.KG88KmWjysp0PNFO5LCZ1g';

  @override
  State<DriverWaitingView> createState() => _DriverWaitingViewState();
}

class _DriverWaitingViewState extends State<DriverWaitingView>
    with SingleTickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  AnimationController? _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) context.read<DriverBloc>().rejectOrder();
        }
      });
  }

  @override
  void dispose() {
    _timerController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DriverWaitingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.status == DriverStatus.hasOrder &&
        oldWidget.state.status != DriverStatus.hasOrder) {
      _handleNewOrder(widget.state.currentOrder!);
      _timerController?.forward(from: 0); // Start timer
    } else if (widget.state.status != DriverStatus.hasOrder &&
        oldWidget.state.status == DriverStatus.hasOrder) {
      _clearOrderRoute();
      _timerController?.stop(); // Stop timer
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Full Screen Map (Dark Heatmap)
          _buildMapBackground(),

          // 2. UI Overlays
          SafeArea(
            child: Column(
              children: [
                if (widget.state.status == DriverStatus.hasOrder)
                  _buildTimerBar(), // Add Timer Bar at top
                if (widget.state.status != DriverStatus.hasOrder)
                  _buildFloatingTopBar(widget.state),
                const Spacer(),
                if (widget.state.status == DriverStatus.hasOrder)
                  _buildNewOrderUI(widget.state.currentOrder!)
                else
                  _buildFloatingBottomPanel(widget.state),
              ],
            ),
          ),

          // 3. Avatar & Tips (Bottom Left)
          Positioned(
            left: 20,
            bottom: 120, // Above the bottom panel
            child: _buildAvatarWithBubble(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return MapWidget(
      styleUri: MapboxStyles.DARK,
      cameraOptions: CameraOptions(
        zoom: 15.0, // Initial Zoom
      ),
      onMapCreated: (MapboxMap mapboxMap) {
        _mapboxMap = mapboxMap;

        // 1. Configure Native Location Puck (Arrow/Bearing)
        _mapboxMap?.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            puckBearingEnabled: true, // Shows arrow/cone based on bearing
          ),
        );

        if (widget.state.status == DriverStatus.hasOrder &&
            widget.state.currentOrder != null) {
          _handleNewOrder(widget.state.currentOrder!);
        } else {
          _centerCameraOnUser();
        }
      },
    );
  }

  Future<void> _centerCameraOnUser() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;

      _mapboxMap?.easeTo(
        CameraOptions(
          center: Point(
              coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
          padding: MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        ),
        MapAnimationOptions(duration: 1200), // Smooth transition
      );
    } catch (e) {
      debugPrint('Error centering map: $e');
    }
  }

  Future<List<Position>> _fetchRouteGeometry(
      Position start, Position end) async {
    try {
      final client = HttpClient();
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/${start.lng},${start.lat};${end.lng},${end.lat}?geometries=geojson&overview=full&access_token=${DriverWaitingView._accessToken}');

      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);

        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates.map<Position>((coord) {
            return Position(coord[0] as num, coord[1] as num);
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
    // Fallback to straight line
    return [start, end];
  }

  Future<void> _handleNewOrder(Order order) async {
    if (_mapboxMap == null) return;

    try {
      final position = await geo.Geolocator.getCurrentPosition();
      final currentPos = Position(position.longitude, position.latitude);
      final pickupPos = Position(
          order.pickupLocation.longitude, order.pickupLocation.latitude);

      // 1. Initialize Managers if needed
      _pointAnnotationManager ??=
          await _mapboxMap!.annotations.createPointAnnotationManager();
      _polylineAnnotationManager ??=
          await _mapboxMap!.annotations.createPolylineAnnotationManager();

      // 2. Add Markers (Start & End)
      final markerImage = await _createMarkerImage(AppColors.accent);

      await _pointAnnotationManager?.create(PointAnnotationOptions(
        geometry: Point(coordinates: pickupPos),
        image: markerImage,
        iconSize: 1.0,
      ));

      // 3. Draw Route (Navigation Style)
      // Fetch actual route geometry
      final routeGeometry = await _fetchRouteGeometry(currentPos, pickupPos);

      await _polylineAnnotationManager?.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: routeGeometry),
        lineColor: Colors.white.value,
        lineWidth: 3.0, // Thinner, high quality
        lineJoin: LineJoin.ROUND,
      ));

      // 4. Fit Bounds with Animation
      if (routeGeometry.isNotEmpty) {
        // Calculate bounds from all points in route for better fit
        double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
        for (final p in routeGeometry) {
          if (p.lat < minLat) minLat = p.lat.toDouble();
          if (p.lat > maxLat) maxLat = p.lat.toDouble();
          if (p.lng < minLng) minLng = p.lng.toDouble();
          if (p.lng > maxLng) maxLng = p.lng.toDouble();
        }

        final padding = 100.0;
        final camera = await _mapboxMap!.cameraForCoordinateBounds(
            CoordinateBounds(
                southwest: Point(coordinates: Position(minLng, minLat)),
                northeast: Point(coordinates: Position(maxLng, maxLat)),
                infiniteBounds: false),
            MbxEdgeInsets(
                top: padding, left: padding, bottom: 300, right: padding),
            0,
            0,
            null,
            null);

        _mapboxMap?.flyTo(
          camera,
          MapAnimationOptions(duration: 1500),
        );
      }
    } catch (e) {
      debugPrint("Error handling new order map update: $e");
    }
  }

  void _clearOrderRoute() async {
    await _pointAnnotationManager?.deleteAll();
    await _polylineAnnotationManager?.deleteAll();
    _centerCameraOnUser(); // Reset camera
  }

  Future<Uint8List> _createMarkerImage(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final radius = 10.0;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
    final picture = recorder.endRecording();
    final img =
        await picture.toImage((radius * 2).toInt(), (radius * 2).toInt());
    return (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Widget _buildNewOrderUI(Order order) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('新訂單！距離 ${order.distance.toStringAsFixed(1)} km',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${order.estimatedMinutes} 分鐘後到達上車點',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<DriverBloc>().rejectOrder();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('拒絕',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<DriverBloc>().acceptOrder();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('接受訂單',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    if (_timerController == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _timerController!,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 1.0 - _timerController!.value, // Count down
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(
                Color.lerp(Colors.green, Colors.red,
                    _timerController!.value)!, // Green -> Red
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingTopBar(DriverState state) {
    final double targetAmount = state.dailyEarningsGoal.toDouble();
    final double progress =
        (state.todayEarnings / targetAmount).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Slim Progress Bar (Attached to top)
        Container(
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ),
        ),
        // Floating Earnings Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withOpacity(0.9), // Dark control bg
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.currency_yen,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                '今日已賺',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${state.todayEarnings}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => _showProfilePage(context),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 28,
              backgroundImage: const AssetImage('assets/images/seal.png'),
              backgroundColor: AppColors.primaryLight,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.zero,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '訂單變多了，快往紅區走！',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.local_fire_department,
                  size: 16, color: AppColors.error),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBottomPanel(DriverState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Modes
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '接單模式',
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildModeChip('標準', true),
                  const SizedBox(width: 8),
                  _buildModeChip('安靜', false),
                ],
              ),
            ],
          ),

          // Offline Button (Slide/Hold Style)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Simple tap for now, can be long press
                  context.read<DriverBloc>().goOffline();
                  _showSnackBar(context, '已下線休息');
                },
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: const [
                      Icon(Icons.power_settings_new,
                          color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text(
                        '下線',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.divider,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
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
