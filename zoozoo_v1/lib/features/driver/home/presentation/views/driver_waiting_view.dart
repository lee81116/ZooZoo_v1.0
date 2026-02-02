import 'dart:async'; // Add this for Timer
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

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

  // Draggable Avatar Position
  double _avatarLeft = 20.0;
  double _avatarBottom = 120.0;
  bool _isAvatarDragging = false;

  // Status message shown at top
  String? _statusMessage;
  double _statusOpacity = 0.0;
  Timer? _statusMessageTimer;

  // Local state for background mode (visual only)
  bool _isBackgroundModeOn = false;

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
    _statusMessageTimer?.cancel();
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
                else ...[
                  // Status message with fade animation
                  if (_statusMessage != null)
                    AnimatedOpacity(
                      opacity: _statusOpacity,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  _buildDrivingModeSelector(widget.state), // New Selector
                  const SizedBox(height: 12),
                  _buildFloatingBottomPanel(widget.state),
                ],
              ],
            ),
          ),

          // 3. Avatar & Tips (Top Left)
          Positioned(
            left: _avatarLeft,
            top: _avatarBottom,
            child: GestureDetector(
              onPanStart: (_) {
                setState(() {
                  _isAvatarDragging = true;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _avatarLeft += details.delta.dx;
                  _avatarBottom += details
                      .delta.dy; // Changed from -= to += for top positioning
                });
              },
              onPanEnd: (_) {
                setState(() {
                  _isAvatarDragging = false;
                });
              },
              onPanCancel: () {
                setState(() {
                  _isAvatarDragging = false;
                });
              },
              child: AnimatedScale(
                scale: _isAvatarDragging ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: _buildAvatarWithBubble(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return MapWidget(
      key: const ValueKey('driver_waiting_map'),
      styleUri: MapboxStyles.DARK,
      cameraOptions: CameraOptions(
        zoom: 15.0, // Initial Zoom
      ),
      onMapCreated: (MapboxMap mapboxMap) {
        _mapboxMap = mapboxMap;

        // Hide Mapbox UI Elements
        _mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
        _mapboxMap?.logo
            .updateSettings(LogoSettings(enabled: false)); // Hide Logo
        _mapboxMap?.attribution.updateSettings(
            AttributionSettings(enabled: false)); // Hide Attribution Button

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
          Text(order.pickupAddress,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              '距離 ${order.distance.toStringAsFixed(1)} km  車程約 ${order.estimatedMinutes} 分鐘',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<DriverBloc>().rejectOrder();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.close_rounded,
                            size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('拒絕',
                            style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<DriverBloc>().acceptOrder();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_rounded,
                            size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('接受',
                            style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 1.0 - _timerController!.value, // Count down
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation(
                    Color.lerp(Colors.green, Colors.red,
                        _timerController!.value)!, // Green -> Red
                  ),
                ),
              ),
            ),
            Text(
              '${((1.0 - _timerController!.value) * 10).ceil()}秒後自動拒絕',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                  )
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingTopBar(DriverState state) {
    final double targetAmount = state.dailyEarningsGoal.toDouble();
    final double progress =
        (state.todayEarnings / targetAmount).clamp(0.0, 1.0);

    // Calculate duration
    String durationText = '0h 0m';
    if (state.onlineSince != null) {
      final duration = DateTime.now().difference(state.onlineSince!);
      durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
    }

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
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ),
        ),

        // Info Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Earnings
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
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
                      '\$${state.todayEarnings}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Online Time
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      durationText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrivingModeSelector(DriverState state) {
    final activeLabels = state.activeModesSafe.map((m) => m.label).join('、');

    return Center(
      child: GestureDetector(
        onTap: () => _showDrivingModeSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '行車模式：$activeLabels',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDrivingModeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<DriverBloc>(
          builder: (context, bloc, child) {
            final state = bloc.state;
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '選擇行車模式',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '標準模式將常駐開啟，可同時選擇其他模式',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: DrivingMode.values.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final mode = DrivingMode.values[index];
                        final isActive = state.activeModesSafe.contains(mode);
                        final isStandard = mode == DrivingMode.standard;

                        return Container(
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryLight.withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: isStandard
                                ? null
                                : () {
                                    bloc.toggleDrivingMode(mode);
                                  },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icon/Check
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isActive
                                            ? AppColors.primary
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: isActive
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              mode.label,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isActive
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                            if (isStandard) ...[
                                              const SizedBox(width: 8),
                                              const Icon(Icons.lock,
                                                  size: 14,
                                                  color:
                                                      AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              const Text('必選',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary)),
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          mode.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '完成',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarWithBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => _showProfilePage(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(_isAvatarDragging ? 0.4 : 0.3),
                  blurRadius: _isAvatarDragging ? 20 : 10,
                  offset: _isAvatarDragging ? const Offset(0, 10) : Offset.zero,
                  spreadRadius: _isAvatarDragging ? 5 : 0,
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 28,
              backgroundImage: AssetImage('assets/images/seal.png'),
              backgroundColor: AppColors.primaryLight,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Hide bubble when dragging for cleaner look? Or keep it? User said "picking up".
        // Usually when picking up an object, attached speech bubbles might fade out or stay attached.
        // Let's keep it but maybe give it a slight lift too or just leave it.
        // The user specifically mentioned "seal", maybe the bubble should detach?
        // Let's keep it simple: the whole group lifts (handled by AnimatedScale parent).
        // Just need to update the shadow of the bubble too?
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
                color: Colors.black.withOpacity(_isAvatarDragging ? 0.2 : 0.1),
                blurRadius: _isAvatarDragging ? 15 : 5,
                offset: _isAvatarDragging ? const Offset(5, 10) : Offset.zero,
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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Toggle Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                icon: !state.isMuted ? Icons.volume_up : Icons.volume_off,
                isActive: !state.isMuted,
                onTap: () {
                  final willBeMuted = !state.isMuted;
                  context.read<DriverBloc>().toggleMute();
                  _showStatusMessage(willBeMuted ? '關閉播報' : '開啟播報');
                },
              ),
              const SizedBox(width: 12),
              _buildToggleButton(
                icon: state.chatVoiceEnabledSafe
                    ? Icons.record_voice_over
                    : Icons.voice_over_off,
                isActive: state.chatVoiceEnabledSafe,
                onTap: () {
                  final willBeEnabled = !state.chatVoiceEnabledSafe;
                  context.read<DriverBloc>().toggleChatVoiceReply();
                  _showStatusMessage(willBeEnabled ? '開啟語音' : '關閉語音');
                },
              ),
              const SizedBox(width: 12),
              _buildBackgroundModeButton(),
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
                  // SnackBar removed
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

  void _showStatusMessage(String message) {
    _statusMessageTimer?.cancel();

    setState(() {
      _statusMessage = message;
      _statusOpacity = 1.0;
    });

    _statusMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _statusOpacity = 0.0;
        });
      }
    });
  }

  Widget _buildBackgroundModeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isBackgroundModeOn = !_isBackgroundModeOn;
        });

        final message = _isBackgroundModeOn ? '背景模式已開啟' : '背景模式已關閉';
        _showStatusMessage(message);

        if (_isBackgroundModeOn) {
          // Delay briefly to show the message
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (Platform.isAndroid) {
              SystemNavigator.pop(); // Minimized on Android
            } else {
              // On iOS, try to open Google Maps to background the app
              final Uri googleMapsUrl = Uri.parse('comgooglemaps://');
              try {
                if (!await launchUrl(googleMapsUrl,
                    mode: LaunchMode.externalApplication)) {
                  throw 'Could not launch Google Maps';
                }
              } catch (e) {
                // Fallback to Google Web if Google Maps is not installed
                final Uri googleWebUrl = Uri.parse('https://www.google.com');
                await launchUrl(googleWebUrl,
                    mode: LaunchMode.externalApplication);
              }
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _isBackgroundModeOn
              ? AppColors.success.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isBackgroundModeOn ? AppColors.success : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          _isBackgroundModeOn ? '背景模式 ON' : '背景模式',
          style: TextStyle(
            color: _isBackgroundModeOn
                ? AppColors.success
                : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.accent : AppColors.textHint,
          size: 24,
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
}
