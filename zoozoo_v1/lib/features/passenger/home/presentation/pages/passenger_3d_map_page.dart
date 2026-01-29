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
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _carAnnotationManager;
  CircleAnnotation? _endAnnotation;
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
  static const _defaultZoom = 17.0; // User requested 17

  final TextEditingController _destinationController = TextEditingController();
  bool _isSearching = false;

  static const String _accessToken =
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjRiMzV5MGV1aDNkb2dzd2J0aGVpNyJ9.khYanFeyddvuxj4ZWqzCyA';

  // 3D Model configuration - Car
  static const _carModelAssetPath = 'assets/3dmodels/base_basic_pbr.glb';
  static const _carModelId = 'car-3d-model';
  static const _carSourceId = 'car-source';
  static const _carLayerId = 'car-layer';

  // Route Config
  static const _routeSourceId = 'route-source';
  static const _routeLayerId = 'route-layer';
  static const _routeColor = Color(0xFFADD8E6); // Light Blue

  // Track if 3D car model is active
  bool _using3DCarModel = false;

  // Smooth rotation tracking
  double _currentBearing = 0.0; // Car's bearing
  double _cameraBearing = 0.0; // Camera's bearing (lagging)
  static const _bearingSmoothFactor = 0.85; // Sharp turn for car
  static const _cameraSmoothFactor = 0.06; // Slow follow for camera

  // Model Calibration: Rotate 180 degrees (User reported car is driving backwards)
  static const _modelCalibration = 180.0;

  bool _isMapUpdating = false;

  @override
  void initState() {
    super.initState();
    _startLocation = widget.startLocation ?? _defaultStart;
    _endLocation = widget.endLocation ?? _defaultEnd;

    // Generate mock road route
    _routeWaypoints = _generateMockRoadRoute(_startLocation, _endLocation);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );

    _animationController.addListener(_onAnimationUpdate);
    _animationController.addStatusListener(_onAnimationStatus);

    // Fetch real route from Mapbox Directions API
    _initializeRealRoute();
  }

  Future<void> _initializeRealRoute() async {
    try {
      final realRoute = await _fetchRoute(_startLocation, _endLocation);
      if (realRoute.isNotEmpty) {
        setState(() {
          _routeWaypoints = realRoute;
        });

        // Redraw route on map if map is already ready
        // Redraw route on map if map is already ready
        if (_mapboxMap != null) {
          // REMOVED: await _drawRoute(); // Caused crash because source/layer already existed
          // Just update the visual state
          _updateCarPosition();
        }
      }
    } catch (e) {
      debugPrint('Error fetching real route: $e Using mock route fallback.');
    }
  }

  Future<List<AppLatLng>> _fetchRoute(AppLatLng start, AppLatLng end) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full&access_token=$_accessToken');

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);

        final routes = json['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>;

          return coordinates.map((coord) {
            final c = coord as List<dynamic>;
            return AppLatLng(c[1].toDouble(), c[0].toDouble()); // lat, lng
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Directions API Error: $e');
      return [];
    } finally {
      client.close();
    }
  }

  Future<void> _searchDestination(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _progress = 0.0; // Reset progress
      _tripState = TripState.notStarted; // Reset trip state
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$_accessToken&limit=1&bbox=120.0,21.5,122.5,26.5'); // Limit to Taiwan roughly

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);

        final features = json['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final center = features[0]['center'] as List<dynamic>;
          final lng = center[0].toDouble();
          final lat = center[1].toDouble();
          final newEnd = AppLatLng(lat, lng);

          setState(() {
            _endLocation = newEnd;
          });

          // Focus map on new destination briefly or fitting bounds could be better,
          // but for now let's just update markers and route.
          await _addLocationMarkers(); // Update end marker

          await _initializeRealRoute(); // Fetch new route

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '已更新目的地: ${features[0]['text_zh-Hant'] ?? features[0]['text']}')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('找不到該地點')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜尋失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
      client.close();
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _animationController.dispose();
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

    // Prevent flooding the platform channel if previous update is still running
    if (!_isMapUpdating) {
      _isMapUpdating = true;
      _updateCarPosition().whenComplete(() {
        _isMapUpdating = false;
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _onTripComplete();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Create managers
    // Create managers
    _circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();

    // Draw route
    await _drawRoute();

    // Add start and end markers (using circles - more reliable than emoji)
    await _addLocationMarkers();

    // Setup lighting for Mapbox Standard style
    await _setupLighting();

    // Setup car marker (always visible as fallback)
    await _setupCarMarker();

    // Try to setup 3D car model
    await _trySetup3DCarModel();

    debugPrint('3D Car model status: $_using3DCarModel');
  }

  Future<void> _drawRoute() async {
    // Initial empty route
    final geoJson = _createLineGeoJson([]);

    // Add Source
    await _mapboxMap!.style.addSource(
      GeoJsonSource(id: _routeSourceId, data: jsonEncode(geoJson)),
    );

    // Add Layer
    await _mapboxMap!.style.addLayer(
      LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        lineColor: _routeColor.value,
        lineWidth: 12.0, // Widened from 6.0
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineEmissiveStrength: 1.0, // Make it glow/ignore lighting
      ),
    );
    // Note: We don't populate data here, it's updated in animation loop
  }

  Map<String, dynamic> _createLineGeoJson(List<List<double>> coordinates) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
          'properties': {},
        },
      ],
    };
  }

  /// Add start and end markers using CircleAnnotation (reliable, no emoji issues)
  Future<void> _addLocationMarkers() async {
    if (_circleAnnotationManager == null) return;

    // Start marker code removed as per request

    // End marker - Red circle (destination/home)
    if (_endAnnotation != null) {
      await _circleAnnotationManager!.delete(_endAnnotation!);
      _endAnnotation = null;
    }

    _endAnnotation = await _circleAnnotationManager!.create(
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
          modelScale: [35.0, 35.0, 35.0],
          modelRotation: [
            0.0,
            0.0,
            0.0
          ], // Initial rotation (will be updated dynamically)
          modelTranslation: [0.0, 0.0, 1.0], // Lift 1m to avoid z-fighting
        ),
      );

      // Enable model animation (wheels spinning, etc.)
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
          _carLayerId,
          'model-animation-enabled',
          true,
        );
        debugPrint('Car model animation enabled');
      } catch (e) {
        debugPrint('Could not enable model animation: $e');
      }

      _using3DCarModel = true;

      // Note: Default animation (usually track 0) might be "Static Pose".
      // We force "running" here based on the user's screenshot.
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
          _carLayerId,
          'model-animation',
          'running', // Lowercase as per screenshot
        );
      } catch (e) {
        debugPrint('Failed to set initial animation: $e');
      }

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

  /// Configure lighting for Mapbox Standard Style
  Future<void> _setupLighting() async {
    if (_mapboxMap == null) return;
    try {
      // Set light preset to "dusk" for dramatic lighting
      // basemap is the default import id for Standard style
      await _mapboxMap!.style.setStyleImportConfigProperty(
        "basemap",
        "lightPreset",
        "dusk",
      );
      debugPrint("Map lighting configured to 'dusk'");
    } catch (e) {
      debugPrint("Failed to set map lighting: $e");
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

  /// Lerp bearing with wrap-around handling (shortest path interpolation)
  double _lerpBearing(double current, double target, double factor) {
    // Normalize bearings to 0-360
    current = current % 360;
    target = target % 360;
    if (current < 0) current += 360;
    if (target < 0) target += 360;

    // Calculate the difference
    double diff = target - current;

    // Handle wrap-around: choose shortest path
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // Apply lerp
    double result = current + diff * factor;

    // Normalize result to 0-360
    result = result % 360;
    if (result < 0) result += 360;

    return result;
  }

  Future<void> _updateCarPosition() async {
    if (_mapboxMap == null) return;

    final state = _calculateRouteState(_progress);
    final position = state.position;
    final targetBearing = state.bearing;

    // Smooth the bearing transition for the CAR
    _currentBearing =
        _lerpBearing(_currentBearing, targetBearing, _bearingSmoothFactor);

    // Smooth the bearing transition for the CAMERA (Lag effect)
    // This allows the car to "turn" visually before the camera catches up
    _cameraBearing =
        _lerpBearing(_cameraBearing, _currentBearing, _cameraSmoothFactor);

    final updates = <Future>[];

    // 1. Update 3D Model (Uses Car Bearing)
    if (_using3DCarModel) {
      try {
        final geoJson = _createPointGeoJson(position, _currentBearing);
        updates.add(_mapboxMap!.style.setStyleSourceProperty(
          _carSourceId,
          'data',
          jsonEncode(geoJson),
        ));

        // CRITICAL FIX: Rotate the model dynamically!
        // Apply (Current Bearing + Calibration Offset)
        updates.add(_mapboxMap!.style.setStyleLayerProperty(
          _carLayerId,
          'model-rotation',
          [0.0, 0.0, _currentBearing + _modelCalibration],
        ));
      } catch (e) {
        debugPrint('Car model update failed: $e');
      }
    }

    // 2. Update Vanishing Route
    try {
      final remainingCoords =
          _getRemainingRouteCoordinates(_progress, position);
      if (remainingCoords.isNotEmpty) {
        final routeGeoJson = _createLineGeoJson(remainingCoords);
        updates.add(_mapboxMap!.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          jsonEncode(routeGeoJson),
        ));
      }
    } catch (e) {
      // Silent fail
    }

    // 3. Icon Fallback (only if car model fails)
    if (_carAnnotation != null &&
        _carAnnotationManager != null &&
        !_using3DCarModel) {
      await _carAnnotationManager!.delete(_carAnnotation!);
      _carAnnotation = await _carAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          iconImage: 'car-icon',
          iconSize: 1.0,
          iconRotate: _currentBearing,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    }

    // 4. Move Camera (Synced but using Camera Bearing)
    // Using setCamera allows smooth frame-by-frame updates without the jitter of flyTo
    updates.add(_mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: _defaultZoom,
        pitch: 70.0, // Adjusted to 70
        bearing: _cameraBearing, // Use Loose Camera Bearing
      ),
    ));

    // Execute efficiently
    try {
      await Future.wait(updates);
    } catch (e) {
      debugPrint('Map update failed: $e');
    }
  }

  /// Get coordinates for the remaining path (Vanishing effect)
  List<List<double>> _getRemainingRouteCoordinates(
      double t, AppLatLng currentPos) {
    if (_routeWaypoints.isEmpty) return [];

    // Calculate split index
    final totalSegments = _routeWaypoints.length - 1;
    // Safety check
    if (totalSegments < 1) return [];

    final currentSegmentIndex = (t * totalSegments).floor();

    // Build list: CurrentPos -> Next Waypoint -> ... -> End
    final coords = <List<double>>[];
    coords.add([currentPos.longitude, currentPos.latitude]);

    for (int i = currentSegmentIndex + 1; i < _routeWaypoints.length; i++) {
      coords.add([_routeWaypoints[i].longitude, _routeWaypoints[i].latitude]);
    }
    return coords;
  }

  /// Calculate both position and bearing based on distance along route
  ({AppLatLng position, double bearing}) _calculateRouteState(double t) {
    if (_routeWaypoints.isEmpty) {
      return (position: _startLocation, bearing: 0.0);
    }

    // 1. Calculate lengths
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

    if (totalLength == 0)
      return (position: _routeWaypoints.first, bearing: 0.0);

    // 2. Find current segment based on distance
    final targetDistance = t * totalLength;
    double accumulated = 0;

    for (int i = 0; i < segmentLengths.length; i++) {
      if (accumulated + segmentLengths[i] >= targetDistance) {
        // Found current segment [i] -> [i+1]
        final segmentT = (targetDistance - accumulated) / segmentLengths[i];
        final start = _routeWaypoints[i];
        final end = _routeWaypoints[i + 1];

        // Interpolate position
        final position = AppLatLng(
          start.latitude + (end.latitude - start.latitude) * segmentT,
          start.longitude + (end.longitude - start.longitude) * segmentT,
        );

        // Calculate bearing for this segment
        final bearing = _calculateBearing(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        );

        return (position: position, bearing: bearing);
      }
      accumulated += segmentLengths[i];
    }

    // Fallback (end of route)
    final last = _routeWaypoints.last;
    final prev = _routeWaypoints[_routeWaypoints.length - 2];
    final finalBearing = _calculateBearing(
        prev.latitude, prev.longitude, last.latitude, last.longitude);

    return (position: last, bearing: finalBearing);
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

  // Animation switching removed for performance and simplicity
  // We rely on the initial 'running' state set in setup.

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
          // if (_showDebugControls) _buildDebugControls(),
        ],
      ),
    );
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
        pitch: 70.0,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          decoration: InputDecoration(
                            hintText: '輸入目的地 (例如: 台北101)',
                            hintStyle: const TextStyle(
                                fontSize: 14, color: AppColors.textHint),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 0),
                            border: InputBorder.none,
                            suffixIcon: _isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ))
                                : IconButton(
                                    icon: const Icon(Icons.search,
                                        size: 20, color: AppColors.primary),
                                    onPressed: () => _searchDestination(
                                        _destinationController.text),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                          ),
                          onSubmitted: _searchDestination,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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
