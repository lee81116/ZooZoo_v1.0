import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // For Random

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../pages/driver_chat_page.dart'; // Import the chat page
import '../../../../../core/models/chat_message.dart';
import '../../../../../core/services/chat_storage_service.dart';

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

class _DriverTripViewState extends State<DriverTripView>
    with SingleTickerProviderStateMixin {
  MapboxMap? _mapboxMap;

  // Annotation Managers (still useful for Destination/Pickup markers)
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _carAnnotationManager; // Fallback icon
  PointAnnotation? _carAnnotation;

  static const String _accessToken =
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjU1MTJhMGN5bjNlczc1Y2o2OWpsNCJ9.KG88KmWjysp0PNFO5LCZ1g';

  // --- 3D Model & Style Config (From Passenger Page) ---

  static const _routeSourceId = 'route-source';
  static const _routeLayerId = 'route-layer';
  static const _routeColor = Colors.white;

  // --- 3D Model Config ---
  static const _carModelAssetPath = 'assets/3dmodels/base_basic_pbr.glb';
  static const _carModelId = 'car-3d-model';
  static const _carSourceId = 'car-source';
  static const _carLayerId = 'car-layer';
  bool _using3DCarModel = false;
  static const _modelCalibration = 180.0;

  StreamSubscription<geo.Position>? _positionStream;

  // --- Voice Service ---
  final FlutterTts _flutterTts = FlutterTts();
  // final stt.SpeechToText _speech = stt.SpeechToText(); // Removed unused
  final stt.SpeechToText _speech = stt.SpeechToText();

  // --- Chat Storage Service ---
  final ChatStorageService _chatStorage = ChatStorageService();

  // --- Navigation Mock State ---
  List<dynamic> _routeSteps = [];
  int _currentStepIndex = 0;
  String _currentInstructionText = "直行";
  String _currentDistanceText = "0 m";
  IconData _currentManeuverIcon = Icons.arrow_upward;

  bool _isPanelExpanded = false;
  late AnimationController _simController;
  VoidCallback? _simListener;

  @override
  void initState() {
    super.initState();
    _simController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _initVoiceServices();
    // Auto-expand for pickup to see address, collapse for trip
    if (widget.state.status == DriverStatus.toPickup) {
      _isPanelExpanded = true;
    }
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
    _simController.dispose();
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
            styleUri: MapboxStyles.DARK,
            cameraOptions: CameraOptions(
              zoom: 17.0,
              pitch: 60.0, // 3D View
            ),
            onMapCreated: _onMapCreated,
          ),

          // 2. UI Overlay
          SafeArea(
            child: Column(
              children: [
                if (_routeSteps.isNotEmpty)
                  _buildNavigationBanner()
                else
                  DriverTopBar(
                    isOnline: true,
                    onProfileTap: () => _showProfilePage(context),
                  ),
                const Spacer(),
                _buildBottomPanel(context, order),
              ],
            ),
          ),

          // 4. Simulate Message Button (Debug)
          Positioned(
            right: 20,
            bottom: 310,
            child: FloatingActionButton(
              heroTag: 'sim_msg_btn',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                // Randomly select one of three questions
                final questions = [
                  "請問還要多久會到？",
                  "可以改地方上車嗎？",
                  "我馬上下去，不好意思請等我一下",
                ];
                final randomQuestion =
                    questions[Random().nextInt(questions.length)];
                _speakAndListen(randomQuestion);
              },
              child: const Icon(Icons.chat, color: Colors.blue),
            ),
          ),
          // 3. Recenter Button (Floating)
          Positioned(
            right: 20,
            bottom: 250, // Approx above bottom panel
            child: FloatingActionButton(
              heroTag: 'recenter_btn',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _centerCameraOnUser,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary, // Used App Theme Color
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _currentManeuverIcon,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentDistanceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentInstructionText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
          lineWidth: 4.0,
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
    // 1. Try 3D Model first
    await _trySetup3DCarModel();

    // 2. Setup Fallback Icon
    if (!_using3DCarModel) {
      await _setupCarIconMarker();
    }
  }

  Future<void> _setupCarIconMarker() async {
    try {
      final ByteData bytes =
          await rootBundle.load('assets/images/vehicles/arrow.png');
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

      final result = await _fetchRouteData(startPos, targetPos);

      final routeGeometry = result['geometry'] as List<List<double>>;
      final routeSteps = result['steps'] as List<dynamic>;

      // 3. Update Route Layer
      if (routeGeometry.isNotEmpty) {
        final geoJson = _createLineGeoJson(routeGeometry);
        await _mapboxMap!.style.setStyleSourceProperty(
            _routeSourceId, "data", jsonEncode(geoJson));
      }

      // Update Step State
      if (routeSteps.isNotEmpty) {
        setState(() {
          _routeSteps = routeSteps;
          _currentStepIndex = 0;
          _updateCurrentStepInfo();
        });
      }

      // 4. Start Auto-Drive Simulation
      _startRouteSimulation(routeGeometry);
    } catch (e) {
      debugPrint("Error updating route: $e");
    }
  }

  void _updateCurrentStepInfo() {
    if (_routeSteps.isEmpty || _currentStepIndex >= _routeSteps.length) return;

    final step = _routeSteps[_currentStepIndex];
    final distance = (step['distance'] as num).toDouble();
    final maneuver = step['maneuver'];
    final instruction = maneuver['instruction'] as String;
    final type = maneuver['type'] as String;
    final modifier = maneuver['modifier'] as String?;

    // Icon mapping
    IconData icon = Icons.arrow_upward;
    if (type == 'turn') {
      if (modifier?.contains('left') == true) icon = Icons.turn_left;
      if (modifier?.contains('right') == true) icon = Icons.turn_right;
    } else if (type == 'arrive') {
      icon = Icons.place;
    }

    // Check for change to trigger voice
    final bool instructionChanged = instruction != _currentInstructionText;

    setState(() {
      _currentInstructionText = instruction;
      _currentDistanceText = distance < 1000
          ? "${distance.toStringAsFixed(0)} m"
          : "${(distance / 1000).toStringAsFixed(1)} km";
      _currentManeuverIcon = icon;
    });

    if (instructionChanged && !widget.state.isMuted) {
      _flutterTts.speak(instruction);
    }
  }

  void _startRouteSimulation(List<List<double>> geometry) {
    if (geometry.length < 2) return;
    _positionStream?.cancel();

    // Calculate segment distances
    final List<double> dists = [0.0];
    for (int i = 0; i < geometry.length - 1; i++) {
      final p1 = geometry[i];
      final p2 = geometry[i + 1];
      final d = geo.Geolocator.distanceBetween(
          p1[1], p1[0], p2[1], p2[0]); // Lat, Lng
      dists.add(dists.last + d);
    }
    final totalDist = dists.last;

    if (_simListener != null) {
      _simController.removeListener(_simListener!);
    }

    _simListener = () {
      if (!mounted || _mapboxMap == null) return;
      final value = _simController.value;
      final currentDist = value * totalDist;

      // Find segment
      int index = dists.length - 2; // Default to last segment
      for (int i = 0; i < dists.length - 1; i++) {
        if (currentDist <= dists[i + 1]) {
          index = i;
          break;
        }
      }

      final p1 = geometry[index];
      final p2 = geometry[index + 1];
      final d1 = dists[index];
      final d2 = dists[index + 1];

      double t = 0.0;
      if (d2 > d1) t = (currentDist - d1) / (d2 - d1);

      final lat = p1[1] + (p2[1] - p1[1]) * t;
      final lng = p1[0] + (p2[0] - p1[0]) * t;

      final bearing = geo.Geolocator.bearingBetween(p1[1], p1[0], p2[1], p2[0]);

      _updateCarVisuals(Position(lng, lat), bearing, lat, lng);
    };

    _simController.addListener(_simListener!);
    _simController.reset();
    _simController.forward();
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
      zoom: 15.0,
      pitch: 60.0,
      bearing: bearing,
      padding: MbxEdgeInsets(top: 0, left: 0, bottom: 200, right: 0),
    ));
  }

  // --- Helpers ---

  Future<Map<String, dynamic>> _fetchRouteData(
      Position start, Position end) async {
    // Fetch from Mapbox Directions API
    final client = HttpClient();
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/${start.lng},${start.lat};${end.lng},${end.lat}?geometries=geojson&overview=full&steps=true&language=zh-TW&access_token=$_accessToken');
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometryData = routes[0]['geometry'];
          final coordinates = geometryData['coordinates'] as List;
          final geometry = coordinates
              .map<List<double>>((c) => [c[0].toDouble(), c[1].toDouble()])
              .toList();

          final legs = routes[0]['legs'] as List;
          final steps = legs.isNotEmpty ? (legs[0]['steps'] as List) : [];

          return {'geometry': geometry, 'steps': steps};
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    // Fallback straight line
    return {
      'geometry': [
        [start.lng.toDouble(), start.lat.toDouble()],
        [end.lng.toDouble(), end.lat.toDouble()]
      ],
      'steps': []
    };
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

  Future<void> _trySetup3DCarModel() async {
    if (_mapboxMap == null) return;
    try {
      final modelUri =
          await _loadModelToTempFile(_carModelAssetPath, 'car.glb');
      await _mapboxMap!.style.addStyleModel(_carModelId, modelUri);

      final geoJson = _createPointGeoJson(Position(121.5, 25.0), 0);
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _carSourceId, data: jsonEncode(geoJson)),
      );

      await _mapboxMap!.style.addLayer(
        ModelLayer(
          id: _carLayerId,
          sourceId: _carSourceId,
          modelId: _carModelId,
          modelScale: [35.0, 35.0, 35.0],
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

  Future<String> _loadModelToTempFile(String assetPath, String tempName) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$tempName');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return 'file://${file.path}';
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
          pitch: 0.0));
    } catch (_) {}
  }

  // --- Voice & Message Logic ---

  Future<void> _speakAndListen(String message) async {
    // Get current order ID
    final orderId = widget.state.currentOrder?.id;
    if (orderId == null) return;

    // 0. Save passenger's voice message to chat
    final passengerMessage = ChatMessage.voice(
      transcribedText: message,
      voiceFilePath:
          "/audio/passenger_${DateTime.now().millisecondsSinceEpoch}.m4a",
      sender: MessageSender.passenger,
    );
    await _chatStorage.addMessage(passengerMessage, orderId);

    // 1. Announce
    await _flutterTts.speak("收到乘客訊息: $message");
    await _flutterTts.awaitSpeakCompletion(true);

    // 2. Listen
    bool available = await _speech.initialize();
    if (available) {
      // Find Chinese Locale
      var locales = await _speech.locales();
      var locale = locales.firstWhere(
        (l) => l.localeId == 'zh_TW' || l.localeId == 'zh-TW',
        orElse: () => locales.firstWhere(
          (l) => l.localeId.startsWith('zh'),
          orElse: () => locales.isNotEmpty
              ? locales.first
              : stt.LocaleName("zh_TW", "zh_TW"), // Fallback manually
        ),
      );

      debugPrint('Selected Locale: ${locale.localeId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("正在聆聽回覆..."),
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ));
      }
      _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            final driverReply = result.recognizedWords;
            debugPrint("Reply: $driverReply");

            // Get current order ID
            final orderId = widget.state.currentOrder?.id;
            if (orderId != null) {
              // Save driver's voice reply to chat
              final driverMessage = ChatMessage.voice(
                transcribedText: driverReply,
                voiceFilePath:
                    "/audio/driver_${DateTime.now().millisecondsSinceEpoch}.m4a",
                sender: MessageSender.driver,
              );
              await _chatStorage.addMessage(driverMessage, orderId);
            }

            // Simulate sending
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("已回覆並儲存: $driverReply"),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
        },
        listenFor: const Duration(seconds: 5),
        localeId: locale.localeId,
      );
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

  Widget _buildBottomPanel(BuildContext context, Order order) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            // Swipe Up
            setState(() => _isPanelExpanded = true);
          } else if (details.primaryVelocity! > 0) {
            // Swipe Down
            setState(() => _isPanelExpanded = false);
          }
        },
        onTap: () {
          if (!_isPanelExpanded) setState(() => _isPanelExpanded = true);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header (Always Visible)
            Row(
              children: [
                Text(
                  _getPanelTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (!_isPanelExpanded)
                  const Icon(Icons.keyboard_arrow_up,
                      color: AppColors.textSecondary),
              ],
            ),

            // Expanded Content
            if (_isPanelExpanded) ...[
              const SizedBox(height: 20),
              // Passenger Info
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
                          order.passenger.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.state.status == DriverStatus.toPickup
                              ? order.pickupAddress
                              : order.destinationAddress,
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
                  // Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircleButton(
                        icon: Icons.phone,
                        color: AppColors.success,
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _buildCircleButton(
                        icon: Icons.chat_bubble_outline,
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const DriverChatPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
              // Main Action Button
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
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  String _getPanelTitle() {
    switch (widget.state.status) {
      case DriverStatus.toPickup:
        return '前往接載乘客';
      case DriverStatus.arrived:
        return '等待乘客上車';
      case DriverStatus.inTrip:
        return '前往目的地';
      default:
        return '行程中';
    }
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
    } else if (widget.state.status == DriverStatus.arrived) {
      context.read<DriverBloc>().startTrip();
      setState(() => _isPanelExpanded = false); // Auto collapse on start trip
    } else if (widget.state.status == DriverStatus.inTrip) {
      context.read<DriverBloc>().completeTrip();
    }
  }
}
