import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../app/router/app_router.dart';
import '../../../../../core/services/map/map_models.dart';
import '../../../../../core/services/map/mapbox_api_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/glass_button.dart';
import '../../../../../core/services/weather_service.dart';
import '../../../../../shared/widgets/rain_effect.dart';
import 'friend_profile_page.dart';
import 'personal_profile_page.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  // Weather state
  final _weatherService = WeatherService();
  WeatherType _currentWeather = WeatherType.clear;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;

  // Initial position (fetched on startup)
  double? _initialLat;
  double? _initialLng;
  bool _locationReady = false;

  // Default fallback location (Taipei 101)
  static const _defaultLat = 25.0330;
  static const _defaultLng = 121.5654;

  // Location Visibility Mode
  _LocationMode _currentLocationMode = _LocationMode.public;
  bool _isLocationMenuExpanded = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Track current destination marker for cleanup
  PointAnnotation? _currentDestinationMarker;
  PointAnnotation? _currentDurationMarker;
  bool _isSearching = false;

  // Pin & Drag mode for fine-tuning destination
  bool _isPinningMode = false;
  String? _pinnedSearchName;

  // Route selection state
  bool _isRouteSelected = false;
  String? _selectedDestinationName;
  double? _selectedDestLat;
  double? _selectedDestLng;

  // Vehicle selection state
  int _selectedVehicleIndex = 0;

  // Options state for Vehicle Selection
  final List<String> _vehicleOptions = ['一般模式', '幫我趕一下', '舒適模式', '安靜模式'];
  Set<String> _selectedVehicleOptions = {'一般模式'};
  bool _showConflictToast = false;
  Timer? _toastTimer;

  Offset? _lastTapDownPosition;

  // Friend markers data for click handling
  List<_MockFriend> _friends = [];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _handleOptionTap(String option) {
    if (option == '幫我趕一下') {
      setState(() {
        if (_selectedVehicleOptions.contains(option)) {
          _selectedVehicleOptions.remove(option);
          // Fallback to General if no specific mode left
          if (!_selectedVehicleOptions.contains('舒適模式')) {
            _selectedVehicleOptions.add('一般模式');
          }
        } else {
          _selectedVehicleOptions.add(option);
          _selectedVehicleOptions.remove('一般模式');
          _selectedVehicleOptions.remove('舒適模式'); // Auto-uncheck Comfort
        }
      });
    } else if (option == '舒適模式') {
      if (_selectedVehicleOptions.contains('幫我趕一下')) {
        _showToast();
        return;
      }
      setState(() {
        if (_selectedVehicleOptions.contains(option)) {
          _selectedVehicleOptions.remove(option);
          if (!_selectedVehicleOptions.contains('幫我趕一下')) {
            _selectedVehicleOptions.add('一般模式');
          }
        } else {
          _selectedVehicleOptions.add(option);
          _selectedVehicleOptions.remove('一般模式');
        }
      });
    } else if (option == '一般模式') {
      setState(() {
        _selectedVehicleOptions.add('一般模式');
        _selectedVehicleOptions.remove('幫我趕一下');
        _selectedVehicleOptions.remove('舒適模式');
      });
    } else if (option == '安靜模式') {
      setState(() {
        if (_selectedVehicleOptions.contains(option)) {
          _selectedVehicleOptions.remove(option);
        } else {
          _selectedVehicleOptions.add(option);
        }
      });
    }
  }

  void _showToast() {
    setState(() {
      _showConflictToast = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showConflictToast = false;
        });
      }
    });
  }

  // 3D Model configuration - Car
  static const _carModelAssetPath = 'assets/3dmodels/base_basic_pbr.glb';
  static const _carModelId = 'car-3d-model';
  static const _carSourceId = 'car-source';
  static const _carLayerId = 'car-layer';
  bool _using3DCarModel = false;
  static const _modelCalibration = 180.0;

  double _currentRouteDistanceMeters = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialLocation();

    // Ensure route is cleared when entering the page (e.g. returning from a completed trip)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearRoute();
    });
  }

  // @override
  // void dispose() {
  //   _searchController.dispose();
  //   _searchFocusNode.dispose();
  //   super.dispose();
  // }
  // Actually, I should just remove it.

  /// Fetch initial location before showing map
  Future<void> _fetchInitialLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      debugPrint('Location permission denied, using default.');
      setState(() {
        _initialLat = _defaultLat;
        _initialLng = _defaultLng;
        _locationReady = true;
      });
      return;
    }

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      debugPrint(
          'Initial location: ${position.latitude}, ${position.longitude}');
      setState(() {
        _initialLat = position.latitude;
        _initialLng = position.longitude;
        _locationReady = true;
      });
    } catch (e) {
      debugPrint('Failed to get initial location: $e. Using default.');
      setState(() {
        _initialLat = _defaultLat;
        _initialLng = _defaultLng;
        _locationReady = true;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Access Token
    MapboxOptions.setAccessToken(
        'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjRiMzV5MGV1aDNkb2dzd2J0aGVpNyJ9.khYanFeyddvuxj4ZWqzCyA');

    // Enable Location Component (Green Puck by default in Standard Style)
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: Colors.green.value,
      puckBearingEnabled: true,
    ));

    // Hide Scale Bar
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Hide Compass
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

    // Hide Logo and Attribution (move off-screen)
    await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(AttributionSettings(
      clickable: false,
      marginBottom: -100,
      marginLeft: -100,
    ));

    // Setup Lighting (Dusk)
    await _setupLighting();

    // Initialize route layer
    const routeSourceId = 'route-source';
    const routeLayerId = 'navigation-route';
    const emptyGeoJson =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}';
    await mapboxMap.style
        .addSource(GeoJsonSource(id: routeSourceId, data: emptyGeoJson));
    await mapboxMap.style.addLayer(LineLayer(
      id: routeLayerId,
      sourceId: routeSourceId,
      lineColor: const Color(0xFFADD8E6).value, // Light Blue matching 3D page
      lineWidth: 8.0,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
      lineEmissiveStrength: 1.0,
    ));

    // Create Annotation Manager
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // Add click listener
    // ignore: deprecated_member_use
    _pointAnnotationManager!.addOnPointAnnotationClickListener(
      _FriendMarkerClickListener(onTap: _handleFriendMarkerTap),
    );

    // Note: Do NOT setup 3D Car Model initially. User wants Green Dot.
    // We will only show Car when in "Navigation/Route Preview" mode if needed,
    // or arguably just keep the dot until the actual 3D Map Page starts.
    // For now, disabling auto-setup of 3D car.
    // await _trySetup3DCarModel();

    // Add Friend Markers
    await _addFriendMarkers(_initialLat!, _initialLng!);
  }

  Future<void> _flyToUserLocation() async {
    if (_mapboxMap == null) return;

    double userLat = _defaultLat;
    double userLng = _defaultLng;

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      userLat = position.latitude;
      userLng = position.longitude;
      debugPrint('User location: $userLat, $userLng');

      // Fetch Weather
      _fetchWeather(userLat, userLng);
    } catch (e) {
      debugPrint('Failed to get user location: $e. Using default.');
    }

    // Fly Camera to User Location
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(userLng, userLat)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1500),
    );

    // Add Friend Markers around user location
    await _addFriendMarkers(userLat, userLng);

    // Update 3D Car Position
    await _updateCarPosition(userLat, userLng, 0);
  }

  /// Handle map tap - check if user tapped on their own location puck
  void _onMapTapped(Offset position) async {
    if (_mapboxMap == null || _initialLat == null || _initialLng == null) {
      return;
    }

    // Get coordinate of the tap
    final tappedPoint = await _mapboxMap!
        .coordinateForPixel(ScreenCoordinate(x: position.dx, y: position.dy));

    // Get current user location (using initial or updated if available)
    double userLat = _initialLat!;
    double userLng = _initialLng!;

    // Calculate Distance
    final dist = geo.Geolocator.distanceBetween(
        tappedPoint.coordinates.lat as double,
        tappedPoint.coordinates.lng as double,
        userLat,
        userLng);

    // Threshold: ~50 meters is generous enough for fingers
    if (dist < 50) {
      debugPrint("Tapped on Self!");
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PersonalProfilePage(),
          ),
        );
      }
    }
  }

  /// Handle tap on friend marker
  void _handleFriendMarkerTap(PointAnnotation annotation) async {
    // Find friend by matching coordinates
    for (final friend in _friends) {
      final coords = annotation.geometry.coordinates;
      if ((coords.lng - friend.lng).abs() < 0.0001 &&
          (coords.lat - friend.lat).abs() < 0.0001) {
        // Navigate to friend profile page
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FriendProfilePage(
              name: friend.name,
              emoji: friend.emoji,
              color: friend.color,
            ),
          ),
        );

        // If returned true, start navigation
        if (result == true) {
          _drawNavigationRoute(friend.lat, friend.lng, friend.name,
              showMarker: false);
        }
        break;
      }
    }
  }

  Future<void> _fetchWeather(double lat, double lng) async {
    final weather = await _weatherService.fetchCurrentWeather(lat, lng);
    if (mounted) {
      setState(() => _currentWeather = weather);
      debugPrint('Current Weather Code: $weather');
    }
  }

  /// Convert emoji + background color to a Uint8List image
  Future<Uint8List> _createEmojiMarkerImage(
      String emoji, Color bgColor, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw colored circle background
    final bgPaint = Paint()..color = bgColor;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 4;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw emoji text
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

  Future<void> _addFriendMarkers(double centerLat, double centerLng) async {
    if (_pointAnnotationManager == null) return;
    await _pointAnnotationManager!.deleteAll();

    _friends = [
      _MockFriend(
        id: 'friend1',
        name: '雪豹先生',
        emoji: '🐆',
        // Taipei 101
        lat: 25.0330,
        lng: 121.5654,
        color: Colors.cyan,
      ),
      _MockFriend(
        id: 'friend2',
        name: '馴鹿小姐',
        emoji: '🦌',
        // Northeast of user
        lat: centerLat + 0.003,
        lng: centerLng + 0.004,
        color: Colors.orange,
      ),
      _MockFriend(
        id: 'friend3',
        name: '棕熊先生',
        emoji: '🐻',
        // Southwest of user
        lat: centerLat - 0.002,
        lng: centerLng - 0.003,
        color: Colors.brown,
      ),
      _MockFriend(
        id: 'friend4',
        name: '灰狼先生',
        emoji: '🐺',
        // Northwest of user
        lat: centerLat + 0.004,
        lng: centerLng - 0.002,
        color: Colors.blueGrey,
      ),
      _MockFriend(
        id: 'friend5',
        name: '紅狐小姐',
        emoji: '🦊',
        // Southeast of user
        lat: centerLat - 0.003,
        lng: centerLng + 0.005,
        color: Colors.deepOrange,
      ),
    ];

    for (final friend in _friends) {
      try {
        // Create emoji marker image (balanced size)
        const markerSize = 110;
        final imageData = await _createEmojiMarkerImage(
            friend.emoji, friend.color, markerSize);

        // Add image to map style
        await _mapboxMap!.style.addStyleImage(
          friend.id,
          2.0,
          MbxImage(width: markerSize, height: markerSize, data: imageData),
          false,
          [],
          [],
          null,
        );

        // Create marker with icon and text label
        await _pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(friend.lng, friend.lat)),
            iconImage: friend.id,
            iconSize: 1.0,
            iconAnchor: IconAnchor.CENTER,
            textField: friend.name,
            textSize: 13.0,
            textAnchor: TextAnchor.TOP,
            textOffset: [0, 2.8],
            textColor: Colors.white.toARGB32(),
            textHaloColor: Colors.black.toARGB32(),
            textHaloWidth: 1.5,
          ),
        );
        debugPrint('Added marker for ${friend.name}');
      } catch (e) {
        debugPrint('Failed to create marker for ${friend.name}: $e');
      }
    }
    debugPrint('Friend markers added: ${_friends.length}');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while fetching initial location
    if (!_locationReady) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Map (initialized at real location)
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              _lastTapDownPosition = event.localPosition;
            },
            onPointerUp: (event) {
              if (_lastTapDownPosition != null) {
                final distance =
                    (event.localPosition - _lastTapDownPosition!).distance;
                if (distance < 10) {
                  // It's a tap
                  _onMapTapped(event.localPosition);
                }
              }
            },
            child: MapWidget(
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(_initialLng!, _initialLat!),
                ),
                zoom: 15.0,
              ),
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: _onMapCreated,
            ),
          ),

          // Rain Effect Overlay
          if (_currentWeather == WeatherType.rain)
            const Positioned.fill(child: RainEffect(isHeavy: false)),
          if (_currentWeather == WeatherType.heavyRain)
            const Positioned.fill(child: RainEffect(isHeavy: true)),

          // 2. Top Bar (Overlay)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    // Location Visibility Toggle
                    _buildLocationVisibilityToggle(),
                    const Spacer(),
                    // Settings Gear Icon + Recenter Button (vertical column)
                    Column(
                      children: [
                        GlassIconButton(
                          icon: Icons.settings_outlined,
                          iconColor: Colors.white,
                          onPressed: () =>
                              context.push(Routes.passengerSettings),
                        ),
                        const SizedBox(height: 12),
                        // Recenter Button (Top Right)
                        GlassIconButton(
                          icon: Icons.my_location,
                          iconColor: AppColors.primary,
                          onPressed: _flyToUserLocation,
                        ),
                        const SizedBox(height: 12),
                        // Friends List Button
                        GlassIconButton(
                          icon: Icons.people,
                          iconColor: Colors.white,
                          onPressed: () {
                            // TODO: Navigate to Friend List Page
                            debugPrint("Open Friends List");
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 3. Draggable Search Sheet (Animated - slides down when route selected or pinning)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: (_isRouteSelected || _isPinningMode) ? -350 : 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Handle
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search Bar (Dark Theme - Solid Background)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.dividerDark,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                _isSearching
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : const Icon(Icons.search,
                                        color: AppColors.primary, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    cursorColor: AppColors.primary,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '搜尋目的地',
                                      hintStyle: TextStyle(
                                        color: AppColors.textHintDark,
                                        fontSize: 16,
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onSubmitted: _handleSearch,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // History Card 1
                        _buildHistoryCard(
                          icon: Icons.history,
                          address: '忠孝東路四段299號',
                          lat: 25.0418,
                          lng: 121.5548,
                        ),
                        const SizedBox(height: 8),

                        // History Card 2
                        _buildHistoryCard(
                          icon: Icons.history,
                          address: '木柵路一段315號',
                          lat: 24.9902,
                          lng: 121.5702,
                        ),

                        const SizedBox(height: 20),

                        // Quick Actions (家, 公司, 最愛) - Rounded Rectangles
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  icon: Icons.home,
                                  label: '家',
                                  onTap: () => _startPinningMode(
                                    25.1321,
                                    121.4986,
                                    '家',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  icon: Icons.business,
                                  label: '公司',
                                  onTap: () => _startPinningMode(
                                    25.0339,
                                    121.5644,
                                    '台北101',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  icon: Icons.favorite,
                                  label: '最愛',
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Pinning Mode UI (center pin + confirm button)
          if (_isPinningMode) ...[
            // Center Pin Icon
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 48,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            // Confirm/Cancel Buttons at Bottom
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instruction Text
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '拖曳地圖調整位置',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmPinnedLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '確認地點',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Cancel Button
                  TextButton(
                    onPressed: _cancelPinningMode,
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Inline Vehicle Selection Sheet (slides up when route is selected)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _isRouteSelected ? 0 : -1000,
            child: _buildInlineVehicleSheet(),
          ),
        ],
      ),
    );
  }

  // --- 3D Model & Lighting Methods ---

  /// Configure lighting for Mapbox Standard Style
  Future<void> _setupLighting() async {
    if (_mapboxMap == null) return;
    try {
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

  /// Try to setup 3D car model
  Future<void> _trySetup3DCarModel() async {
    if (_mapboxMap == null) return;

    // Use initial location
    final lat = _initialLat ?? _defaultLat;
    final lng = _initialLng ?? _defaultLng;

    try {
      debugPrint('Loading car model to temp file...');
      final modelUri =
          await _loadModelToTempFile(_carModelAssetPath, 'car.glb');

      // Add model to style
      await _mapboxMap!.style.addStyleModel(
        _carModelId,
        modelUri,
      );

      // Create GeoJSON source
      final geoJson = _createPointGeoJson(lat, lng, 0); // bearing 0
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
          modelRotation: [0.0, 0.0, _modelCalibration],
          modelTranslation: [0.0, 0.0, 1.0],
        ),
      );

      // Enable model animation
      try {
        await _mapboxMap!.style.setStyleLayerProperty(
          _carLayerId,
          'model-animation-enabled',
          true,
        );
      } catch (_) {}

      _using3DCarModel = true;
      debugPrint('3D car model setup successful on Home Page!');
    } catch (e) {
      debugPrint('3D car model setup failed: $e');
      _using3DCarModel = false;

      // Fallback: Enable default location puck if 3D fails
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ));
    }
  }

  Future<String> _loadModelToTempFile(String assetPath, String tempName) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$tempName');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return 'file://${file.path}';
  }

  Map<String, dynamic> _createPointGeoJson(
      double lat, double lng, double bearing) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [lng, lat],
          },
          'properties': {
            'bearing': bearing,
          },
        },
      ],
    };
  }

  /// Update car position (if we need to move it)
  Future<void> _updateCarPosition(
      double lat, double lng, double bearing) async {
    if (!_using3DCarModel || _mapboxMap == null) return;

    try {
      final geoJson = _createPointGeoJson(lat, lng, bearing);
      await _mapboxMap!.style.setStyleSourceProperty(
        _carSourceId,
        'data',
        jsonEncode(geoJson),
      );

      // Update rotation
      await _mapboxMap!.style.setStyleLayerProperty(
        _carLayerId,
        'model-rotation',
        [0.0, 0.0, bearing + _modelCalibration],
      );
    } catch (_) {}
  }

  /// Build location visibility toggle button (top-left)
  Widget _buildLocationVisibilityToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate max expanded width: screen - padding(40) - buttons(48) - margin(16)
    final maxExpandedWidth = (screenWidth - 40 - 48 - 16).clamp(180.0, 260.0);

    return GestureDetector(
      onTap: _isLocationMenuExpanded
          ? null
          : () => setState(() => _isLocationMenuExpanded = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: 48,
        width: _isLocationMenuExpanded ? maxExpandedWidth : 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isLocationMenuExpanded
            ? _buildExpandedLocationMenu()
            : _buildCollapsedLocationIcon(),
      ),
    );
  }

  /// Collapsed state: show only the current mode icon
  Widget _buildCollapsedLocationIcon() {
    return Center(
      child: Icon(
        _getLocationModeIcon(_currentLocationMode),
        color: _getLocationModeColor(_currentLocationMode),
        size: 24,
      ),
    );
  }

  /// Expanded state: show all three options
  Widget _buildExpandedLocationMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLocationOption(_LocationMode.public, '公開'),
        _buildLocationOption(_LocationMode.friends, '摯友'),
        _buildLocationOption(_LocationMode.off, '關閉'),
      ],
    );
  }

  /// Individual option in expanded menu
  Widget _buildLocationOption(_LocationMode mode, String label) {
    final isSelected = _currentLocationMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentLocationMode = mode;
          _isLocationMenuExpanded = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? _getLocationModeColor(mode).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getLocationModeIcon(mode),
              color: _getLocationModeColor(mode),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? _getLocationModeColor(mode) : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get icon for location mode
  IconData _getLocationModeIcon(_LocationMode mode) {
    switch (mode) {
      case _LocationMode.public:
        return Icons.circle;
      case _LocationMode.friends:
        return Icons.star;
      case _LocationMode.off:
        return Icons.circle;
    }
  }

  /// Get color for location mode
  Color _getLocationModeColor(_LocationMode mode) {
    switch (mode) {
      case _LocationMode.public:
      case _LocationMode.friends:
        return Colors.lightGreenAccent;
      case _LocationMode.off:
        return Colors.grey;
    }
  }

  /// Build inline vehicle selection sheet (slides up from bottom)
  Widget _buildInlineVehicleSheet() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Top Section: Conflict Toast (Floating) + Vehicle Options (Floating/Transparent)
        // Conflict Toast
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showConflictToast ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '趕時間時無法選擇舒適模式',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Vehicle Options Row (Transparent Background)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _vehicleOptions.map((option) {
              final isSelected = _selectedVehicleOptions.contains(option);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _handleOptionTap(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE0E0E0)
                          : Colors.white, // Selected is darker
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check,
                                size: 16, color: Colors.black),
                          ),
                        Text(
                          option,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Main Sheet Content (Dark Background)
        Container(
          height: 480 + bottomPadding,
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header with title, destination, and close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '選擇車型',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_currentWeather == WeatherType.rain)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            Colors.blue.withValues(alpha: 0.5)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Text('🌧️',
                                          style: TextStyle(fontSize: 12)),
                                      SizedBox(width: 4),
                                      Text(
                                        'x1.15',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_currentWeather == WeatherType.heavyRain)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            Colors.red.withValues(alpha: 0.5)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Text('⛈️',
                                          style: TextStyle(fontSize: 12)),
                                      SizedBox(width: 4),
                                      Text(
                                        'x1.3',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (_selectedDestinationName != null)
                            Builder(builder: (context) {
                              final arrivalTime = DateTime.now().add(Duration(
                                  seconds:
                                      _currentRouteDurationSeconds.toInt()));
                              final eta =
                                  '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';

                              return Text(
                                '前往 $_selectedDestinationName, 預計$eta抵達',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _clearRoute,
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Vehicle Options List
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setSheetState) {
                    // Calculate prices dynamically
                    final priceDog = _calculatePrice('元氣汪汪');
                    final priceCat = _calculatePrice('招財貓貓');
                    final priceBear = _calculatePrice('北極熊阿北');

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildVehicleOption(
                          name: '元氣汪汪',
                          emoji: '🐕',
                          price: 'NT\$$priceDog',
                          time: '3 分鐘',
                          subtitle: '標準速速',
                          isSelected: _selectedVehicleIndex == 0,
                          onTap: () =>
                              setSheetState(() => _selectedVehicleIndex = 0),
                        ),
                        _buildVehicleOption(
                          name: '招財貓貓',
                          emoji: '🐱',
                          price: 'NT\$$priceCat',
                          time: '5 分鐘',
                          subtitle: '尊榮速速',
                          isSelected: _selectedVehicleIndex == 1,
                          onTap: () =>
                              setSheetState(() => _selectedVehicleIndex = 1),
                        ),
                        _buildVehicleOption(
                          name: '北極熊阿北',
                          emoji: '🐻‍❄️',
                          price: 'NT\$$priceBear',
                          time: '8 分鐘',
                          subtitle: '減碳速速',
                          isSelected: _selectedVehicleIndex == 2,
                          onTap: () =>
                              setSheetState(() => _selectedVehicleIndex = 2),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Dark Coffee Block Footer
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 16),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Confirm Button
                    GestureDetector(
                      onTap: () {
                        final priceDog = _calculatePrice('元氣汪汪');
                        final priceCat = _calculatePrice('招財貓貓');
                        final priceBear = _calculatePrice('北極熊阿北');

                        // Navigate to waiting page
                        context.push(
                          Routes.passengerBooking,
                          extra: {
                            'userLocation': AppLatLng(
                              _initialLat ?? _defaultLat,
                              _initialLng ?? _defaultLng,
                            ),
                            'destinationLocation': AppLatLng(
                              _selectedDestLat ?? _defaultLat,
                              _selectedDestLng ?? _defaultLng,
                            ),
                            'vehicleType': [
                              '元氣汪汪',
                              '招財貓貓',
                              '北極熊阿北'
                            ][_selectedVehicleIndex],
                            'price': [
                              priceDog,
                              priceCat,
                              priceBear
                            ][_selectedVehicleIndex],
                          },
                        );

                        // IMMEDIATELY reset home page state
                        _clearRoute();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            '確認預約',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  /// Build a vehicle option tile
  Widget _buildVehicleOption({
    required String name,
    required String emoji,
    required String price,
    required String time,
    required bool isSelected,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.dividerDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),

            // Name and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '預計 $time 抵達',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Price & Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  // Removed box decoration as requested
                  Container(
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12, // Increased from 10 to 12 (+2)
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required IconData icon,
    required String address,
    required double lat,
    required double lng,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => _startPinningMode(lat, lng, address),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _currentRouteDurationSeconds = 0;

  Future<void> _drawNavigationRoute(
      double destLat, double destLng, String destName,
      {bool showMarker = true}) async {
    if (_mapboxMap == null) return;

    final userLat = _initialLat ?? _defaultLat;
    final userLng = _initialLng ?? _defaultLng;

    const sourceId = 'route-source';

    try {
      // Get real route from Mapbox Directions API
      final routeResult = await MapboxApiService.getRoute(
        startLat: userLat,
        startLng: userLng,
        endLat: destLat,
        endLng: destLng,
      );

      String geoJson;
      if (routeResult != null) {
        // Use real route geometry
        geoJson = routeResult.toGeoJson();
        _currentRouteDistanceMeters = routeResult.distanceMeters;
        _currentRouteDurationSeconds = routeResult.durationSeconds;
        debugPrint(
            'Route: ${(routeResult.distanceMeters / 1000).toStringAsFixed(1)}km, '
            '${(routeResult.durationSeconds / 60).toStringAsFixed(0)}min');
      } else {
        // Fallback to straight line if API fails
        _currentRouteDistanceMeters =
            _calculateDistance(userLat, userLng, destLat, destLng);
        // Estimate duration based on 30km/h average speed (8.33 m/s)
        _currentRouteDurationSeconds = _currentRouteDistanceMeters / 8.33;

        geoJson = '''
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": [
              [$userLng, $userLat],
              [$destLng, $destLat]
            ]
          }
        }
        ''';
      }

      // Update existing source data (layer was created in _onMapCreated)
      final source = await _mapboxMap!.style.getSource(sourceId);
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geoJson);
      }

      // Add destination marker (clears previous) - skip for friend navigation
      if (showMarker) {
        await _addDestinationMarker(destLat, destLng, destName);
      }

      // Fly camera to center between user and destination
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              (userLng + destLng) / 2,
              (userLat + destLat) / 2,
            ),
          ),
          zoom: 13.0,
          pitch: 60.0, // Add pitch for 3D effect
        ),
        MapAnimationOptions(duration: 1500),
      );

      // Add duration marker at midpoint
      if (showMarker) {
        final durationText =
            '${(_currentRouteDurationSeconds / 60).toStringAsFixed(0)} min';

        // Calculate midpoint strictly from route geometry if possible
        double midLat = (userLat + destLat) / 2;
        double midLng = (userLng + destLng) / 2;

        // If we have a complex route, finding the true midpoint would be better,
        // but for now, geometric center is a reasonable approximation for the marker placement.
        await _addDurationMarker(midLat, midLng, durationText);
      }

      // Set route selected state
      if (mounted) {
        setState(() {
          _isRouteSelected = true;
          _selectedDestinationName = destName;
          _selectedDestLat = destLat;
          _selectedDestLng = destLng;
        });
      }

      debugPrint('Navigation route drawn to $destName');
    } catch (e) {
      debugPrint('Failed to draw navigation route: $e');
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return math.sqrt(dLat * dLat + dLng * dLng) * 111000;
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

  int _calculatePrice(String type) {
    // 1. Base Fare
    double total = 85.0;

    // 2. Surcharges
    // Night Surcharge (23:00 - 06:00)
    final now = DateTime.now();
    final isNight = now.hour >= 23 || now.hour < 6;
    if (isNight) {
      total += 25.0;
    }

    // Lunar New Year Surcharge (2026/02/16 - 2026/02/22)
    final isSpringFestival = now.isAfter(DateTime(2026, 2, 16)) &&
        now.isBefore(DateTime(2026, 2, 23));
    if (isSpringFestival) {
      total += 40.0;
    }

    // 3. Distance Charge
    // Over 1.25km (1250m), add $5.5 per 200m
    if (_currentRouteDistanceMeters > 1250) {
      final extraMeters = _currentRouteDistanceMeters - 1250;
      final units = extraMeters / 200;
      total += units * 5;
    }

    // 4. Time Charge
    // Peak: 07:00-09:00 or 16:30-19:00 -> $5.0/min
    // Off-peak -> $3.0/min
    final currentHour = now.hour + now.minute / 60.0;
    final bool isPeak = (currentHour >= 7.0 && currentHour < 9.0) ||
        (currentHour >= 16.5 && currentHour < 19.0);

    double timeRate = isPeak ? 5.0 : 3.0;

    // Adjust time rate based on distance
    if (_currentRouteDistanceMeters >= 5000 &&
        _currentRouteDistanceMeters <= 6000) {
      timeRate -= 2.0;
    } else if (_currentRouteDistanceMeters > 7000) {
      timeRate += 2.0;
    }

    final durationMinutes = _currentRouteDurationSeconds / 60;
    total += durationMinutes * timeRate;

    // 5. Weather Multiplier
    double weatherMultiplier = 1.0;
    if (_currentWeather == WeatherType.heavyRain) {
      weatherMultiplier = 1.3;
    } else if (_currentWeather == WeatherType.rain) {
      weatherMultiplier = 1.15;
    }
    total *= weatherMultiplier;

    // 6. Vehicle Type Multiplier (Optional/Existing logic)
    if (type == '招財貓貓') {
      total *= 1.5;
    }

    // 7. Final Rounding (Ceiling)
    return total.ceil();
  }

  /// Clear route and reset to search mode
  Future<void> _clearRoute() async {
    const sourceId = 'route-source';
    const emptyGeoJson =
        '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}';

    try {
      // Clear route by setting empty data (keep layer intact for z-order)
      try {
        final source = await _mapboxMap!.style.getSource(sourceId);
        if (source is GeoJsonSource) {
          await source.updateGeoJSON(emptyGeoJson);
        }
      } catch (_) {}

      // Remove destination marker
      if (_currentDestinationMarker != null) {
        try {
          await _pointAnnotationManager!.delete(_currentDestinationMarker!);
          _currentDestinationMarker = null;
        } catch (_) {}
      }

      // Remove duration marker
      if (_currentDurationMarker != null) {
        try {
          await _pointAnnotationManager!.delete(_currentDurationMarker!);
          _currentDurationMarker = null;
        } catch (_) {}
      }

      // Reset state
      setState(() {
        _isRouteSelected = false;
        _selectedDestinationName = null;
        _selectedDestLat = null;
        _selectedDestLng = null;
        _currentRouteDistanceMeters = 0;
      });

      // Fly back to user location
      await _flyToUserLocation();

      // Return camera to user location
      if (_initialLat != null && _initialLng != null) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(_initialLng!, _initialLat!),
            ),
            zoom: 15.0,
            pitch: 0.0,
          ),
          MapAnimationOptions(duration: 1000),
        );
      }
    } catch (e) {
      debugPrint('Error clearing route: $e');
    }
  }

  /// Handle search submission - real Mapbox geocoding
  /// Enters pinning mode to allow user to fine-tune location
  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;

    _searchFocusNode.unfocus();

    setState(() => _isSearching = true);

    try {
      // Real geocoding via Mapbox API
      final result = await MapboxApiService.getCoordinates(query);

      if (result != null) {
        _searchController.clear();
        await _startPinningMode(
          result.latitude,
          result.longitude,
          result.placeName,
        );
      } else {
        // Show error if location not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('找不到「$query」的位置'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// Start pinning mode - fly to location and show pin for fine-tuning
  Future<void> _startPinningMode(double lat, double lng, String name) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    if (mounted) {
      setState(() {
        _isPinningMode = true;
        _pinnedSearchName = name;
      });
    }
  }

  /// Confirm the pinned location and draw route
  Future<void> _confirmPinnedLocation() async {
    if (_mapboxMap == null) return;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;
      final lat = center.coordinates.lat.toDouble();
      final lng = center.coordinates.lng.toDouble();

      setState(() => _isPinningMode = false);

      await _drawNavigationRoute(lat, lng, _pinnedSearchName ?? '自訂地點');
    } catch (e) {
      debugPrint('Error confirming pinned location: $e');
    }
  }

  /// Cancel pinning mode
  void _cancelPinningMode() {
    setState(() {
      _isPinningMode = false;
      _pinnedSearchName = null;
    });
  }

  /// Add a destination pin marker (removes previous one first)
  Future<void> _addDestinationMarker(
      double lat, double lng, String name) async {
    if (_pointAnnotationManager == null) return;

    const markerId = 'destination-marker';

    try {
      // Remove previous destination marker if exists
      if (_currentDestinationMarker != null) {
        try {
          await _pointAnnotationManager!.delete(_currentDestinationMarker!);
          _currentDestinationMarker = null;
        } catch (_) {}
      }

      // Create pin marker image
      final imageData = await _createPinMarkerImage();

      // Remove existing style image if any (to refresh)
      try {
        await _mapboxMap!.style.removeStyleImage(markerId);
      } catch (_) {}

      // Add image to style
      await _mapboxMap!.style.addStyleImage(
        markerId,
        2.0,
        MbxImage(width: 80, height: 100, data: imageData),
        false,
        [],
        [],
        null,
      );

      // Create new destination marker and store reference
      _currentDestinationMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconImage: markerId,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
          textField: name,
          textSize: 14.0,
          textOffset: [0, 0.5],
          textColor: Colors.white.toARGB32(),
          textHaloColor: Colors.black.toARGB32(),
          textHaloWidth: 1.5,
        ),
      );
      debugPrint('Destination marker added: $name');
    } catch (e) {
      debugPrint('Failed to add destination marker: $e');
    }
  }

  /// Add a duration marker (bubble)
  Future<void> _addDurationMarker(double lat, double lng, String text) async {
    if (_pointAnnotationManager == null) return;

    const markerId = 'duration-marker';

    try {
      // Remove previous duration marker if exists
      if (_currentDurationMarker != null) {
        try {
          await _pointAnnotationManager!.delete(_currentDurationMarker!);
          _currentDurationMarker = null;
        } catch (_) {}
      }

      // Create duration marker image
      final imageData = await _createDurationMarkerImage(text);

      // Remove existing style image if any
      try {
        await _mapboxMap!.style.removeStyleImage(markerId);
      } catch (_) {}

      // Add image to style
      await _mapboxMap!.style.addStyleImage(
        markerId,
        2.0,
        MbxImage(width: 120, height: 60, data: imageData),
        false,
        [],
        [],
        null,
      );

      // Create new duration marker
      _currentDurationMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconImage: markerId,
          iconSize: 1.0,
          // iconAnchor: IconAnchor.CENTER, // Center on the line
          textField: text, // Redundant if baked into image, but good for debug
          textSize: 0.0, // Hide text field, showing image only
        ),
      );
    } catch (e) {
      debugPrint('Failed to add duration marker: $e');
    }
  }

  /// Create a duration bubble image
  Future<Uint8List> _createDurationMarkerImage(String text) async {
    const width = 120;
    const height = 60;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background bubble
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Add shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 5, width - 10.0, height - 10.0),
      const Radius.circular(20),
    );

    canvas.drawRRect(rrect.shift(const Offset(2, 2)), shadowPaint);
    canvas.drawRRect(rrect, bgPaint);

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: width - 20.0);
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Create a simple pin marker image
  Future<Uint8List> _createPinMarkerImage() async {
    const width = 80;
    const height = 100;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw pin shape
    final pinPaint = Paint()..color = Colors.red;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Circle head
    const circleCenter = Offset(width / 2, 30);
    const circleRadius = 25.0;
    canvas.drawCircle(circleCenter, circleRadius, pinPaint);
    canvas.drawCircle(circleCenter, circleRadius, strokePaint);

    // Inner white dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(circleCenter, 8, dotPaint);

    // Pin point (triangle)
    final path = Path()
      ..moveTo(width / 2 - 15, 50)
      ..lineTo(width / 2, 90)
      ..lineTo(width / 2 + 15, 50)
      ..close();
    canvas.drawPath(path, pinPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

/// Location visibility mode for the user
enum _LocationMode {
  public, // 公開 - Green circle
  friends, // 摯友 - Green star
  off, // 關閉 - Gray circle
}

class _MockFriend {
  final String id;
  final String name;
  final String emoji;
  final double lat;
  final double lng;
  final Color color;

  _MockFriend({
    required this.id,
    required this.name,
    required this.emoji,
    required this.lat,
    required this.lng,
    required this.color,
  });
}

/// Click listener for friend markers
// ignore: deprecated_member_use
class _FriendMarkerClickListener implements OnPointAnnotationClickListener {
  final void Function(PointAnnotation) onTap;

  _FriendMarkerClickListener({required this.onTap});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onTap(annotation);
  }
}
