import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/map/map_models.dart';

/// 3D Map page with car simulation for ride tracking
class Passenger3DMapPage extends StatefulWidget {
  final AppLatLng? startLocation;
  final AppLatLng? endLocation;
  final String? vehicleType;
  final int? price;

  const Passenger3DMapPage({
    super.key,
    this.startLocation,
    this.endLocation,
    this.vehicleType,
    this.price,
  });

  @override
  State<Passenger3DMapPage> createState() => _Passenger3DMapPageState();
}

enum TripState { notStarted, inProgress, arrived }

class _Passenger3DMapPageState extends State<Passenger3DMapPage>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _carAnnotationManager;
  PointAnnotation? _carAnnotation;

  // Animation
  late AnimationController _animationController;
  TripState _tripState = TripState.notStarted;
  double _progress = 0.0;

  // Locations
  late AppLatLng _startLocation;
  late AppLatLng _endLocation;

  // Mock road route waypoints
  late List<AppLatLng> _routeWaypoints;

  // Default: Taipei 101 area
  static const _defaultStart = AppLatLng(25.0330, 121.5654);
  static const _defaultEnd = AppLatLng(25.0400, 121.5700);
  static const _defaultZoom = 16.0;

  // House location (near route)
  static const _houseLocation = AppLatLng(25.0350, 121.5680);

  // 3D Model configuration - Car
  static const _carModelAssetPath = 'assets/3dmodels/toy_car.glb';
  static const _carModelId = 'car-3d-model';
  static const _carSourceId = 'car-source';
  static const _carLayerId = 'car-layer';

  // 3D Model configuration - House
  static const _houseModelAssetPath = 'assets/3dmodels/wood_house.glb';
  static const _houseModelId = 'house-3d-model';
  static const _houseSourceId = 'house-source';
  static const _houseLayerId = 'house-layer';

  // Track if 3D models are active
  bool _using3DCarModel = false;
  bool _using3DHouseModel = false;

  // Debug variables
  double _currentScale = 500.0;
  double _currentAltitude = 0.0;
  bool _showDebugControls = true;

  @override
  void initState() {
    super.initState();
    _startLocation = widget.startLocation ?? _defaultStart;
    _endLocation = widget.endLocation ?? _defaultEnd;

    // Generate mock road route
    _routeWaypoints = _generateMockRoadRoute(_startLocation, _endLocation);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _animationController.addListener(_onAnimationUpdate);
    _animationController.addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _polylineManager = null;
    _circleAnnotationManager = null;
    _carAnnotationManager = null;
    super.dispose();
  }

  /// Generate a mock road route with waypoints that simulate road turns
  List<AppLatLng> _generateMockRoadRoute(AppLatLng start, AppLatLng end) {
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;

    return [
      start,
      AppLatLng(start.latitude, midLng),
      AppLatLng(midLat, midLng),
      AppLatLng(midLat, end.longitude),
      AppLatLng(end.latitude - 0.002, end.longitude),
      end,
    ];
  }

  void _onAnimationUpdate() {
    setState(() {
      _progress = _animationController.value;
    });
    _updateCarPosition();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _onTripComplete();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Create managers
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();

    // Draw route
    await _drawRoute();

    // Add start and end markers (using circles - more reliable than emoji)
    await _addLocationMarkers();

    // Setup car marker (always visible as fallback)
    await _setupCarMarker();

    // Try to setup 3D car model
    await _trySetup3DCarModel();

    // Try to setup 3D house model
    await _trySetup3DHouseModel();

    // Report 3D model status
    debugPrint(
        '3D Models status - Car: $_using3DCarModel, House: $_using3DHouseModel');
  }

  Future<void> _drawRoute() async {
    if (_polylineManager == null) return;

    final coordinates =
        _routeWaypoints.map((p) => Position(p.longitude, p.latitude)).toList();

    await _polylineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coordinates),
        lineColor: AppColors.primary.toARGB32(),
        lineWidth: 6.0,
      ),
    );
  }

  /// Add start and end markers using CircleAnnotation (reliable, no emoji issues)
  Future<void> _addLocationMarkers() async {
    if (_circleAnnotationManager == null) return;

    // Start marker - Green circle
    await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            _startLocation.longitude,
            _startLocation.latitude,
          ),
        ),
        circleColor: Colors.green.toARGB32(),
        circleRadius: 12.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3.0,
      ),
    );

    // End marker - Red circle (destination/home)
    await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            _endLocation.longitude,
            _endLocation.latitude,
          ),
        ),
        circleColor: Colors.red.toARGB32(),
        circleRadius: 12.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3.0,
      ),
    );

    debugPrint('Location markers created (green=start, red=end)');
  }

  /// Setup car marker using icon image (fallback for 3D model)
  Future<void> _setupCarMarker() async {
    try {
      // Load car icon from assets
      final ByteData bytes =
          await rootBundle.load('assets/images/vehicles/dog.png');
      final Uint8List list = bytes.buffer.asUint8List();

      // Add image to map style
      await _mapboxMap!.style.addStyleImage(
        'car-icon',
        4.0,
        MbxImage(width: 100, height: 100, data: list),
        false,
        [],
        [],
        null,
      );

      // Create annotation manager
      _carAnnotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();

      // Create marker with icon
      _carAnnotation = await _carAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _startLocation.longitude,
              _startLocation.latitude,
            ),
          ),
          iconImage: 'car-icon',
          iconSize: 1.0,
          iconRotate: 0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );

      debugPrint('Car icon marker created');
    } catch (e) {
      debugPrint('Failed to create car icon marker: $e');
    }
  }

  /// Try to setup 3D car model (toy_car.glb) using File API
  Future<void> _trySetup3DCarModel() async {
    if (_mapboxMap == null) return;

    try {
      debugPrint('Loading car model to temp file...');
      final modelUri =
          await _loadModelToTempFile(_carModelAssetPath, 'car.glb');
      debugPrint('Car model loaded at: $modelUri');

      // Add model to style
      await _mapboxMap!.style.addStyleModel(
        _carModelId,
        modelUri,
      );

      // Create GeoJSON source
      final geoJson = _createPointGeoJson(_startLocation, 0);
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _carSourceId, data: jsonEncode(geoJson)),
      );

      // Create ModelLayer
      await _mapboxMap!.style.addLayer(
        ModelLayer(
          id: _carLayerId,
          sourceId: _carSourceId,
          modelId: _carModelId,
          modelScale: [500.0, 500.0, 500.0],
          modelRotation: [0.0, 0.0, 0.0],
          modelTranslation: [0.0, 0.0, 0.0],
        ),
      );

      _using3DCarModel = true;

      // Hide icon marker since 3D model is working
      if (_carAnnotation != null && _carAnnotationManager != null) {
        await _carAnnotationManager!.delete(_carAnnotation!);
        _carAnnotation = null;
      }

      debugPrint('3D car model setup successful!');
    } catch (e) {
      debugPrint('3D car model setup failed: $e');
      _using3DCarModel = false;
    }
  }

  /// Try to setup 3D house model (wood_house.glb)
  Future<void> _trySetup3DHouseModel() async {
    if (_mapboxMap == null) return;

    try {
      debugPrint('Loading house model to temp file...');
      final modelUri =
          await _loadModelToTempFile(_houseModelAssetPath, 'house.glb');

      // Add model to style
      await _mapboxMap!.style.addStyleModel(
        _houseModelId,
        modelUri,
      );

      // Create GeoJSON source at fixed location
      final geoJson = _createPointGeoJson(_houseLocation, 0);
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _houseSourceId, data: jsonEncode(geoJson)),
      );

      // Create ModelLayer
      await _mapboxMap!.style.addLayer(
        ModelLayer(
          id: _houseLayerId,
          sourceId: _houseSourceId,
          modelId: _houseModelId,
          modelScale: [500.0, 500.0, 500.0],
          modelRotation: [0.0, 0.0, 0.0],
          modelTranslation: [0.0, 0.0, 0.0],
        ),
      );

      _using3DHouseModel = true;
      debugPrint('3D house model setup successful');
    } catch (e) {
      debugPrint('3D house model setup failed: $e');
      _using3DHouseModel = false;
    }
  }

  /// Helper: Load asset to temp file and return URI
  Future<String> _loadModelToTempFile(String assetPath, String tempName) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$tempName');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return 'file://${file.path}';
  }

  Map<String, dynamic> _createPointGeoJson(AppLatLng position, double bearing) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.longitude, position.latitude],
          },
          'properties': {
            'bearing': bearing,
          },
        },
      ],
    };
  }

  void _updateCarPosition() async {
    if (_mapboxMap == null) return;

    final position = _interpolateAlongRoute(_progress);
    final bearing = _calculateBearingAlongRoute(_progress);

    // Update 3D car model position if active
    if (_using3DCarModel) {
      try {
        final geoJson = _createPointGeoJson(position, bearing);
        await _mapboxMap!.style.setStyleSourceProperty(
          _carSourceId,
          'data',
          jsonEncode(geoJson),
        );
      } catch (e) {
        debugPrint('Failed to update 3D car model: $e');
      }
    }

    // Update icon marker position (if still active as fallback)
    if (_carAnnotation != null && _carAnnotationManager != null) {
      await _carAnnotationManager!.delete(_carAnnotation!);
      _carAnnotation = await _carAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          iconImage: 'car-icon',
          iconSize: 1.0,
          iconRotate: bearing,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    }

    // Move camera to follow car
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: _defaultZoom,
        pitch: 60.0,
        bearing: bearing,
      ),
      MapAnimationOptions(duration: 100),
    );
  }

  /// Interpolate position along the route waypoints
  AppLatLng _interpolateAlongRoute(double t) {
    if (_routeWaypoints.isEmpty) return _startLocation;
    if (t <= 0) return _routeWaypoints.first;
    if (t >= 1) return _routeWaypoints.last;

    double totalLength = 0;
    final segmentLengths = <double>[];

    for (int i = 0; i < _routeWaypoints.length - 1; i++) {
      final length = _distanceBetween(
        _routeWaypoints[i],
        _routeWaypoints[i + 1],
      );
      segmentLengths.add(length);
      totalLength += length;
    }

    final targetDistance = t * totalLength;
    double accumulated = 0;

    for (int i = 0; i < segmentLengths.length; i++) {
      if (accumulated + segmentLengths[i] >= targetDistance) {
        final segmentT = (targetDistance - accumulated) / segmentLengths[i];
        final start = _routeWaypoints[i];
        final end = _routeWaypoints[i + 1];

        return AppLatLng(
          start.latitude + (end.latitude - start.latitude) * segmentT,
          start.longitude + (end.longitude - start.longitude) * segmentT,
        );
      }
      accumulated += segmentLengths[i];
    }

    return _routeWaypoints.last;
  }

  double _calculateBearingAlongRoute(double t) {
    if (_routeWaypoints.length < 2) return 0;

    final segmentIndex = (t * (_routeWaypoints.length - 1)).floor();
    final clampedIndex = segmentIndex.clamp(0, _routeWaypoints.length - 2);

    final start = _routeWaypoints[clampedIndex];
    final end = _routeWaypoints[clampedIndex + 1];

    return _calculateBearing(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  double _distanceBetween(AppLatLng a, AppLatLng b) {
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    var bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  void _startTrip() {
    setState(() {
      _tripState = TripState.inProgress;
      _progress = 0.0;
    });

    _animationController.forward(from: 0.0);
  }

  void _onTripComplete() {
    setState(() {
      _tripState = TripState.arrived;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        context.go('/passenger');
      }
    });
  }

  String _formatTimeRemaining() {
    final remainingSeconds = ((1 - _progress) * 15).round();
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    if (minutes > 0) {
      return '$minutes 分 $seconds 秒';
    }
    return '$seconds 秒';
  }

  @override
  Widget build(BuildContext context) {
    if (const bool.fromEnvironment('dart.library.js_util')) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D Simulation')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text('Mapbox 3D SDK supports Android & iOS only'),
              Text('Please run on a mobile device',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.vehicleType != null
            ? '${widget.vehicleType} 前往目的地'
            : '前往目的地'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: _tripState == TripState.notStarted,
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildBottomCard(),
          if (_showDebugControls) _buildDebugControls(),
        ],
      ),
    );
  }

  Widget _buildDebugControls() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text('3D Model Debugger',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Scale:', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _currentScale,
                    min: 1.0,
                    max: 2000.0,
                    onChanged: (val) {
                      setState(() => _currentScale = val);
                      _updateModelProperties();
                    },
                  ),
                ),
                Text(_currentScale.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
            Row(
              children: [
                const Text('Alt (Z):', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _currentAltitude,
                    min: -50.0,
                    max: 100.0,
                    onChanged: (val) {
                      setState(() => _currentAltitude = val);
                      _updateModelProperties();
                    },
                  ),
                ),
                Text(_currentAltitude.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateModelProperties() async {
    if (_mapboxMap == null) return;
    try {
      if (_using3DCarModel) {
        await _mapboxMap!.style.setStyleLayerProperty(
            _carLayerId,
            'model-scale',
            jsonEncode([_currentScale, _currentScale, _currentScale]));
        await _mapboxMap!.style.setStyleLayerProperty(_carLayerId,
            'model-translation', jsonEncode([0.0, 0.0, _currentAltitude]));
      }
      if (_using3DHouseModel) {
        await _mapboxMap!.style.setStyleLayerProperty(
            _houseLayerId,
            'model-scale',
            jsonEncode(
                [_currentScale / 2, _currentScale / 2, _currentScale / 2]));
        await _mapboxMap!.style.setStyleLayerProperty(_houseLayerId,
            'model-translation', jsonEncode([0.0, 0.0, _currentAltitude]));
      }
    } catch (e) {
      debugPrint('Failed to update options: $e');
    }
  }

  Widget _buildMap() {
    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            _startLocation.longitude,
            _startLocation.latitude,
          ),
        ),
        zoom: _defaultZoom,
        pitch: 60.0,
        bearing: 30.0,
      ),
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: _onMapCreated,
    );
  }

  Widget _buildBottomCard() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _buildCardContent(),
      ),
    );
  }

  Widget _buildCardContent() {
    switch (_tripState) {
      case TripState.notStarted:
        return _buildNotStartedContent();
      case TripState.inProgress:
        return _buildInProgressContent();
      case TripState.arrived:
        return _buildArrivedContent();
    }
  }

  Widget _buildNotStartedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_taxi,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vehicleType ?? '司機已到達',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const Text(
                    '準備出發前往目的地',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.price != null)
              Text(
                '\$${widget.price}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppColors.success,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _startTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '開始行程',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.navigation,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '行程進行中',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    '預計 ${_formatTimeRemaining()} 後到達',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildArrivedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 32,
              ),
              SizedBox(width: 12),
              Text(
                '已到達目的地！',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.price != null)
          Text(
            '車資 \$${widget.price}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          '感謝您的搭乘！',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
