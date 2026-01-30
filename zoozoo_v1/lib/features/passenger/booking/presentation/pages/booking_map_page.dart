import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../core/services/map/map_models.dart';
import '../../../../../core/services/map/mapbox_api_service.dart';
import '../../../../../core/theme/app_colors.dart';

/// Waiting for Driver page - shows driver approaching on map
class BookingMapPage extends StatefulWidget {
  final AppLatLng? userLocation;
  final AppLatLng? destinationLocation;
  final String? vehicleType;
  final int? price;

  const BookingMapPage({
    super.key,
    this.userLocation,
    this.destinationLocation,
    this.vehicleType,
    this.price,
  });

  @override
  State<BookingMapPage> createState() => _BookingMapPageState();
}

class _BookingMapPageState extends State<BookingMapPage>
    with SingleTickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;

  // Default locations (fallback)
  static const _defaultUserLat = 25.0330;
  static const _defaultUserLng = 121.5654;

  // Computed locations
  late double _userLat;
  late double _userLng;
  late double _driverStartLat;
  late double _driverStartLng;

  // Route coordinates from API
  List<List<double>> _routeCoordinates = [];
  int _currentRouteIndex = 0;

  // Current driver position
  late double _driverLat;
  late double _driverLng;

  // Animation
  Timer? _animationTimer;
  PointAnnotation? _driverMarker;
  bool _isRouteLoaded = false;

  // Driver info
  final String _driverName = '北極熊阿北';
  final String _driverEmoji = '🐻‍❄️';
  final String _vehiclePlate = 'ABC-1234';

  // Route source/layer IDs
  static const _routeSourceId = 'driver-route-source';
  static const _routeLayerId = 'driver-route-layer';

  @override
  void initState() {
    super.initState();

    // Use passed locations or defaults
    _userLat = widget.userLocation?.latitude ?? _defaultUserLat;
    _userLng = widget.userLocation?.longitude ?? _defaultUserLng;

    // Driver starts ~500m away from user
    _driverStartLat = _userLat + 0.005;
    _driverStartLng = _userLng - 0.005;

    _driverLat = _driverStartLat;
    _driverLng = _driverStartLng;
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  String get _vehicleType => widget.vehicleType ?? '元氣汪汪';

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Access Token
    MapboxOptions.setAccessToken(
        'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjRiMzV5MGV1aDNkb2dzd2J0aGVpNyJ9.khYanFeyddvuxj4ZWqzCyA');

    // Hide UI elements
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(AttributionSettings(
      clickable: false,
      marginBottom: -100,
      marginLeft: -100,
    ));

    // Enable location
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));

    // Initialize route layer first (so it's below markers)
    await _initializeRouteLayer();

    // Create annotation manager
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // Fetch route and start simulation
    await _fetchRouteAndStart();
  }

  Future<void> _initializeRouteLayer() async {
    const emptyGeoJson =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}';

    await _mapboxMap!.style
        .addSource(GeoJsonSource(id: _routeSourceId, data: emptyGeoJson));

    await _mapboxMap!.style.addLayer(LineLayer(
      id: _routeLayerId,
      sourceId: _routeSourceId,
      lineColor: Colors.white.toARGB32(),
      lineWidth: 5.0,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
  }

  Future<void> _fetchRouteAndStart() async {
    // Fetch real route from Mapbox Directions API
    final routeResult = await MapboxApiService.getRoute(
      startLat: _driverStartLat,
      startLng: _driverStartLng,
      endLat: _userLat,
      endLng: _userLng,
    );

    if (routeResult != null && routeResult.coordinates.isNotEmpty) {
      _routeCoordinates = routeResult.coordinates;
    } else {
      // Fallback: straight line
      _routeCoordinates = [
        [_driverStartLng, _driverStartLat],
        [_userLng, _userLat],
      ];
    }

    setState(() => _isRouteLoaded = true);

    // Draw initial route
    await _updateRouteLine();

    // Add markers
    await _addUserMarker();
    await _addDriverMarker();

    // Start animation
    _startRouteAnimation();
  }

  Future<void> _updateRouteLine() async {
    if (_mapboxMap == null || _routeCoordinates.isEmpty) return;

    // Get remaining route from current index to end
    final remainingCoords = _routeCoordinates.sublist(_currentRouteIndex);

    if (remainingCoords.isEmpty) return;

    final coordsJson =
        remainingCoords.map((c) => '[${c[0]}, ${c[1]}]').join(', ');

    final geoJson = '''
    {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [$coordsJson]
      }
    }
    ''';

    try {
      final source = await _mapboxMap!.style.getSource(_routeSourceId);
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geoJson);
      }
    } catch (e) {
      debugPrint('Failed to update route line: $e');
    }
  }

  Future<void> _addUserMarker() async {
    if (_pointAnnotationManager == null) return;

    try {
      // Create circular user marker
      final imageData = await _createCircleMarker(Colors.green, 80);

      await _mapboxMap!.style.addStyleImage(
        'user-marker',
        2.0,
        MbxImage(width: 80, height: 80, data: imageData),
        false,
        [],
        [],
        null,
      );

      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(_userLng, _userLat)),
          iconImage: 'user-marker',
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
          textField: '',
          textSize: 12.0,
          textAnchor: TextAnchor.TOP,
          textOffset: [0, 2.5],
          textColor: Colors.white.toARGB32(),
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 1.5,
        ),
      );
    } catch (e) {
      debugPrint('Failed to add user marker: $e');
    }
  }

  Future<void> _addDriverMarker() async {
    if (_pointAnnotationManager == null) return;

    try {
      // Create square driver marker
      final imageData = await _createSquareDriverMarker(_driverEmoji, 120);

      await _mapboxMap!.style.addStyleImage(
        'driver-marker',
        2.0,
        MbxImage(width: 120, height: 120, data: imageData),
        false,
        [],
        [],
        null,
      );

      _driverMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLng, _driverLat)),
          iconImage: 'driver-marker',
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
          textField: _driverName,
          textSize: 13.0,
          textAnchor: TextAnchor.TOP,
          textOffset: [0, 3.0],
          textColor: Colors.white.toARGB32(),
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 1.5,
        ),
      );
    } catch (e) {
      debugPrint('Failed to add driver marker: $e');
    }
  }

  /// Create circular marker
  Future<Uint8List> _createCircleMarker(Color color, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final center = Offset(size / 2, size / 2);
    final radius = (size - 8) / 2;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawCircle(center, radius, borderPaint);

    // Inner dot
    canvas.drawCircle(center, radius * 0.3, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Create square driver marker with emoji
  Future<Uint8List> _createSquareDriverMarker(String emoji, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw rounded square background
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size - 8.0, size - 8.0),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);

    // Draw emoji
    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size * 0.5),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _startRouteAnimation() {
    if (_routeCoordinates.isEmpty) return;

    // Calculate interval: 10 seconds total, divided by number of points
    const totalDuration = 10000; // 10 seconds in ms
    final interval = totalDuration ~/ _routeCoordinates.length;

    _animationTimer = Timer.periodic(
      Duration(milliseconds: interval.clamp(50, 500)),
      (timer) {
        if (_currentRouteIndex >= _routeCoordinates.length - 1) {
          timer.cancel();
          _onDriverArrived();
          return;
        }

        _currentRouteIndex++;
        final coord = _routeCoordinates[_currentRouteIndex];

        setState(() {
          _driverLng = coord[0];
          _driverLat = coord[1];
        });

        _updateDriverMarkerPosition();
        _updateRouteLine();
      },
    );
  }

  Future<void> _updateDriverMarkerPosition() async {
    if (_driverMarker == null || _pointAnnotationManager == null) return;

    try {
      _driverMarker!.geometry = Point(
        coordinates: Position(_driverLng, _driverLat),
      );
      await _pointAnnotationManager!.update(_driverMarker!);
    } catch (e) {
      debugPrint('Failed to update driver position: $e');
    }
  }

  void _onDriverArrived() {
    // Navigate to 3D map after short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        // Start location is user's current location (where driver picked up)
        // End location is the destination selected by user
        context.pushReplacement(
          Routes.passenger3DMap,
          extra: {
            'startLocation': AppLatLng(_userLat, _userLng),
            'endLocation': widget.destinationLocation ??
                const AppLatLng(_defaultUserLat + 0.01, _defaultUserLng + 0.01),
            'vehicleType': _vehicleType,
            'price': widget.price ?? 120,
          },
        );
      }
    });
  }

  double get _progress {
    if (_routeCoordinates.isEmpty) return 0.0;
    return _currentRouteIndex / (_routeCoordinates.length - 1);
  }

  String _getETA() {
    if (_routeCoordinates.isEmpty) return '計算中...';
    final remaining = 1.0 - _progress;
    final seconds = (remaining * 10).round();
    if (seconds <= 0) return '已抵達';
    return '$seconds 秒';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  (_userLng + _driverStartLng) / 2,
                  (_userLat + _driverStartLat) / 2,
                ),
              ),
              zoom: 14.0,
            ),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
          ),

          // Loading indicator
          if (!_isRouteLoaded)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.dividerDark,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom panel - Driver info
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status text
                      const Text(
                        '司機正在趕來...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Driver info row
                      Row(
                        children: [
                          // Driver avatar
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                _driverEmoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Driver details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driverName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_vehicleType • $_vehiclePlate',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ETA
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getETA(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          minHeight: 8,
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
}
