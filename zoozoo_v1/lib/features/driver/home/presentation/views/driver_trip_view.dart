import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:path_provider/path_provider.dart'; // For 3D model loading
import 'package:provider/provider.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../pages/driver_chat_page.dart'; // Import the chat page

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

  // Annotation Managers (still useful for Destination/Pickup markers)
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _carAnnotationManager; // Fallback icon
  PointAnnotation? _carAnnotation;

  static const String _accessToken =
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjU1MTJhMGN5bjNlczc1Y2o2OWpsNCJ9.KG88KmWjysp0PNFO5LCZ1g';

  // --- 3D Model & Style Config (From Passenger Page) ---
  static const _carModelAssetPath = 'assets/3dmodels/base_basic_pbr.glb';
  static const _carModelId = 'car-3d-model';
  static const _carSourceId = 'car-source';
  static const _carLayerId = 'car-layer';

  static const _routeSourceId = 'route-source';
  static const _routeLayerId = 'route-layer';
  static const _routeColor = Color(0xFFADD8E6); // Light Blue

  bool _using3DCarModel = false;

  // Smooth rotation tracking
  double _currentBearing = 0.0;
  double _cameraBearing = 0.0;
  static const _bearingSmoothFactor = 0.85;
  static const _cameraSmoothFactor = 0.06;
  static const _modelCalibration = 180.0; // Fix car facing backwards

  StreamSubscription<geo.Position>? _positionStream;

  // --- Voice Service ---
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initVoiceServices();

    // Simulate a message after 3 seconds for demo purposes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _simulateIncomingMessage();
    });
  }

  Future<void> _initVoiceServices() async {
    await _flutterTts.setLanguage("zh-TW");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void didUpdateWidget(DriverTripView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.status != oldWidget.state.status ||
        widget.state.currentOrder?.id != oldWidget.state.currentOrder?.id) {
      _updateRoute();
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _circleAnnotationManager = null;
    _carAnnotationManager = null;
    super.dispose();
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
            key: const ValueKey("driver_nav_map"),
            styleUri: MapboxStyles.STANDARD, // Use Standard Style (3D)
            cameraOptions: CameraOptions(
              zoom: 17.0,
              pitch: 60.0, // Initial driving pitch
            ),
            onMapCreated: _onMapCreated,
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

  // --- Map Setup ---

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Set Token
    MapboxOptions.setAccessToken(_accessToken);

    // Hide Mapbox UI Elements
    try {
      await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
      await mapboxMap.attribution
          .updateSettings(AttributionSettings(enabled: false));
    } catch (e) {
      debugPrint("Error hiding Mapbox UI: $e");
    }

    // 1. Setup Lighting
    await _setupLighting();

    // 2. Setup Annotation Managers (for Pickup/Dropoff markers)
    _circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();

    // 3. Setup Route Layer (Empty initially)
    await _setupRouteLayer();

    // 4. Setup Car (3D Model or Icon)
    await _setupCarLayer();

    // 5. Initial Camera Center & Start Tracking
    await _centerCameraOnUser();

    // 6. Draw Route if needed
    _updateRoute();
  }

  Future<void> _setupLighting() async {
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.style
          .setStyleImportConfigProperty("basemap", "lightPreset", "dusk");
    } catch (e) {
      debugPrint("Failed to set lighting: $e");
    }
  }

  Future<void> _setupRouteLayer() async {
    if (_mapboxMap == null) return;
    try {
      final geoJson = _createLineGeoJson([]);
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _routeSourceId, data: jsonEncode(geoJson)),
      );

      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineColor: _routeColor.value,
          lineWidth: 10.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineEmissiveStrength: 1.0,
        ),
      );
    } catch (e) {
      debugPrint("Failed to setup route layer: $e");
    }
  }

  Future<void> _setupCarLayer() async {
    // 1. Try 3D Model
    await _trySetup3DCarModel();

    // 2. Setup Fallback Icon (always good to have or if 3D fails)
    if (!_using3DCarModel) {
      await _setupCarIconMarker();
    }
  }

  Future<void> _trySetup3DCarModel() async {
    if (_mapboxMap == null) return;
    try {
      final modelUri =
          await _loadModelToTempFile(_carModelAssetPath, 'car.glb');
      await _mapboxMap!.style.addStyleModel(_carModelId, modelUri);

      // Dummy initial position
      final geoJson = _createPointGeoJson(Position(121.5, 25.0), 0);

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _carSourceId, data: jsonEncode(geoJson)),
      );

      await _mapboxMap!.style.addLayer(
        ModelLayer(
          id: _carLayerId,
          sourceId: _carSourceId,
          modelId: _carModelId,
          modelScale: [35.0, 35.0, 35.0], // Match passenger page
          modelRotation: [0.0, 0.0, 0.0],
          modelTranslation: [0.0, 0.0, 0.5],
        ),
      );

      // Enable Animation
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
            _carLayerId, 'model-animation-enabled', true);
        await _mapboxMap!.style.setStyleLayerProperty(
            _carLayerId, 'model-animation', 'running' // Default animation
            );
      } catch (_) {}

      _using3DCarModel = true;
    } catch (e) {
      debugPrint("3D Setup Failed: $e");
      _using3DCarModel = false;
    }
  }

  Future<void> _setupCarIconMarker() async {
    try {
      final ByteData bytes =
          await rootBundle.load('assets/images/vehicles/dog.png');
      final Uint8List list = bytes.buffer.asUint8List();
      await _mapboxMap!.style.addStyleImage('car-icon', 3.0,
          MbxImage(width: 100, height: 100, data: list), false, [], [], null);

      _carAnnotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
    } catch (e) {
      debugPrint("Icon setup failed: $e");
    }
  }

  // --- Logic ---

  Future<void> _updateRoute() async {
    if (_mapboxMap == null) return;
    final order = widget.state.currentOrder;
    if (order == null) return;

    // 0. Clean up markers
    await _circleAnnotationManager?.deleteAll();

    // 1. Determine Target & Show Marker
    Position? targetPos;
    if (widget.state.status == DriverStatus.toPickup) {
      targetPos = Position(
          order.pickupLocation.longitude, order.pickupLocation.latitude);
      await _addCircleMarker(targetPos, Colors.green); // Green for Pickup
    } else if (widget.state.status == DriverStatus.inTrip) {
      targetPos = Position(order.destinationLocation.longitude,
          order.destinationLocation.latitude);
      await _addCircleMarker(targetPos, Colors.red); // Red for Destination
    }

    if (targetPos == null) return;

    // 2. Fetch Route
    try {
      final currentPos = await geo.Geolocator.getCurrentPosition();
      final startPos = Position(currentPos.longitude, currentPos.latitude);

      final routeGeometry = await _fetchRouteGeometry(startPos, targetPos);

      // 3. Update Route Layer
      if (routeGeometry.isNotEmpty) {
        final geoJson = _createLineGeoJson(routeGeometry);
        await _mapboxMap!.style.setStyleSourceProperty(
            _routeSourceId, "data", jsonEncode(geoJson));
      }

      // 4. Start Navigation Loop
      _startMockNavigationLoop(
          startPos); // Using "Mock" naming but it's real loc loop now
    } catch (e) {
      debugPrint("Error updating route: $e");
    }
  }

  void _startMockNavigationLoop(Position startPos) {
    _positionStream?.cancel();

    // Continuous Tracking
    const locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    // Initial positioning
    _updateCarVisuals(
        startPos, 0, startPos.lat.toDouble(), startPos.lng.toDouble());

    _positionStream =
        geo.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((pos) {
      if (!mounted) return;
      _handleLocationUpdate(pos);
    });
  }

  void _handleLocationUpdate(geo.Position pos) {
    // 1. Calculate Bearings
    double targetBearing =
        pos.heading; // Device heading often noisy, but okay for real driving

    // Only update bearing if moving (speed > 1 m/s approx 3.6 km/h) to avoid spinning at lights
    if (pos.speed < 1.0) {
      targetBearing = _currentBearing;
    }

    // Smooth model bearing
    _currentBearing =
        _lerpBearing(_currentBearing, targetBearing, _bearingSmoothFactor);

    // Smooth camera bearing (lag)
    _cameraBearing =
        _lerpBearing(_cameraBearing, _currentBearing, _cameraSmoothFactor);

    // 2. Update Visuals
    final currentPos = Position(pos.longitude, pos.latitude);
    _updateCarVisuals(currentPos, _currentBearing, pos.latitude, pos.longitude);
  }

  Future<void> _updateCarVisuals(
      Position pos, double bearing, double lat, double lng) async {
    if (_mapboxMap == null) return;

    // A. Update 3D Model
    if (_using3DCarModel) {
      final geoJson = _createPointGeoJson(pos, bearing);
      await _mapboxMap!.style
          .setStyleSourceProperty(_carSourceId, 'data', jsonEncode(geoJson));
      await _mapboxMap!.style.setStyleLayerProperty(_carLayerId,
          'model-rotation', [0.0, 0.0, bearing + _modelCalibration]);
    }
    // B. Update Icon (Fallback)
    else if (_carAnnotationManager != null) {
      if (_carAnnotation != null) {
        await _carAnnotationManager!.delete(_carAnnotation!);
      }
      _carAnnotation =
          await _carAnnotationManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: pos),
        iconImage: 'car-icon',
        iconRotate: bearing,
      ));
    }

    // C. Update Camera
    _mapboxMap!.setCamera(CameraOptions(
      center: Point(coordinates: pos),
      zoom: 17.5,
      pitch: 65.0,
      bearing: _cameraBearing, // Use lagged camera bearing
      padding: MbxEdgeInsets(top: 0, left: 0, bottom: 200, right: 0),
    ));
  }

  // --- Helpers ---

  Future<String> _loadModelToTempFile(String assetPath, String tempName) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$tempName');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return 'file://${file.path}';
  }

  Future<List<List<double>>> _fetchRouteGeometry(
      Position start, Position end) async {
    // Fetch from Mapbox Directions API
    final client = HttpClient();
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/${start.lng},${start.lat};${end.lng},${end.lat}?geometries=geojson&overview=full&access_token=$_accessToken');
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          // Convert [lng, lat] dynamic list to double list
          return coordinates
              .map<List<double>>((c) => [c[0].toDouble(), c[1].toDouble()])
              .toList();
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    // Fallback straight line
    return [
      [start.lng.toDouble(), start.lat.toDouble()],
      [end.lng.toDouble(), end.lat.toDouble()]
    ];
  }

  Map<String, dynamic> _createLineGeoJson(List<List<double>> coordinates) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
          'properties': {}
        }
      ]
    };
  }

  Map<String, dynamic> _createPointGeoJson(Position pos, double bearing) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [pos.lng, pos.lat]
          },
          'properties': {'bearing': bearing}
        }
      ]
    };
  }

  double _lerpBearing(double current, double target, double factor) {
    // Normalize to 0-360
    current = current % 360;
    target = target % 360;
    if (current < 0) current += 360;
    if (target < 0) target += 360;

    double diff = target - current;
    if (diff > 180)
      diff -= 360;
    else if (diff < -180) diff += 360;

    double result = current + diff * factor;
    result = result % 360;
    if (result < 0) result += 360;
    return result;
  }

  Future<void> _addCircleMarker(Position pos, Color color) async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager!.create(CircleAnnotationOptions(
      geometry: Point(coordinates: pos),
      circleColor: color.value,
      circleRadius: 10.0,
      circleStrokeColor: Colors.white.value,
      circleStrokeWidth: 3.0,
    ));
  }

  Future<void> _centerCameraOnUser() async {
    try {
      final pos = await geo.Geolocator.getCurrentPosition();
      _mapboxMap?.setCamera(CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 17.0,
          pitch: 60.0));
    } catch (_) {}
  }

  // --- Voice & Message Logic ---

  void _simulateIncomingMessage() {
    const message = "司機你好，我大概五分鐘後到";
    _showSnackBar(context, "收到乘客訊息: $message");
    _speakAndListen(message);
  }

  Future<void> _speakAndListen(String message) async {
    // 1. Speak (if Voice Broadcast is enabled)
    if (!widget.state.isMuted) {
      await _flutterTts.speak("收到乘客訊息：$message。請回覆。");

      // Wait for speech to finish or use delay
      await Future.delayed(const Duration(seconds: 4));
    }

    // 2. Listen (if Chat Voice Reply is enabled)
    if (widget.state.chatVoiceEnabledSafe) {
      bool available = await _speech.initialize();
      if (available) {
        if (!mounted) return;
        setState(() => _isListening = true);
        _showSnackBar(context, "正在錄音回覆 (5秒)...");

        await _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
            });
          },
          localeId: "zh_TW",
        );

        // Stop after 5 seconds
        await Future.delayed(const Duration(seconds: 5));
        await _speech.stop();

        if (!mounted) return;
        setState(() => _isListening = false);

        // 3. Send Reply
        if (_lastWords.isNotEmpty) {
          _showSnackBar(context, "已發送回覆: $_lastWords");
          if (!widget.state.isMuted) {
            _flutterTts.speak("已發送：$_lastWords");
          }
          _lastWords = ''; // Reset
        } else {
          if (!widget.state.isMuted) {
            _flutterTts.speak("未偵測到語音，已取消回覆。");
          }
        }
      } else {
        debugPrint("The user has denied the use of speech recognition.");
      }
    }
  }

  // --- Existing UI Logic ---

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phone Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone,
                          color: AppColors.success, size: 20),
                      onPressed: () => _showSnackBar(context, '撥打電話功能開發中'),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chat Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: AppColors.primary, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DriverChatPage()),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                  // Debug/Simulate Button (Tiny, for demo)
                  GestureDetector(
                    onLongPress: _simulateIncomingMessage,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 20,
                      height: 20,
                      color: Colors.transparent,
                      child: const Center(
                          child: Icon(Icons.bug_report,
                              size: 12, color: Colors.grey)),
                    ),
                  ),
                ],
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
}
