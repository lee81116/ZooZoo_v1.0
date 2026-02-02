import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../app/router/app_router.dart';
import '../../../../../core/services/map/map_models.dart';
import '../../../../../core/services/map/mapbox_api_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/glass_button.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
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
  bool _isSearching = false;

  // Route selection state
  bool _isRouteSelected = false;
  String? _selectedDestinationName;
  double? _selectedDestLat;
  double? _selectedDestLng;

  // Cancel button reveal state
  double _cancelRevealOffset = 0.0;
  bool _isCancelRevealed = false;

  // Vehicle selection state
  int _selectedVehicleIndex = 0;

  // Friend markers data for click handling
  List<_MockFriend> _friends = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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

    // Enable Location Component (Blue Puck)
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
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

    // Initialize route layer BEFORE annotations (ensures route is below markers)
    const routeSourceId = 'route-source';
    const routeLayerId = 'navigation-route';
    const emptyGeoJson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}';
    await mapboxMap.style.addSource(GeoJsonSource(id: routeSourceId, data: emptyGeoJson));
    await mapboxMap.style.addLayer(LineLayer(
      id: routeLayerId,
      sourceId: routeSourceId,
      lineColor: Colors.white.toARGB32(),
      lineWidth: 5.0,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));

    // Create Annotation Manager (after route layer, so annotations are on top)
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    // Add click listener for friend markers
    // ignore: deprecated_member_use
    _pointAnnotationManager!.addOnPointAnnotationClickListener(
      _FriendMarkerClickListener(onTap: _handleFriendMarkerTap),
    );

    // Add Friend Markers around initial location (no extra fly needed)
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
  }

  /// Handle tap on friend marker
  void _handleFriendMarkerTap(PointAnnotation annotation) {
    // Find friend by matching coordinates
    for (final friend in _friends) {
      final coords = annotation.geometry.coordinates;
      if ((coords.lng - friend.lng).abs() < 0.0001 &&
          (coords.lat - friend.lat).abs() < 0.0001) {
        // Navigate to friend without showing red pin (friend marker already exists)
        _drawNavigationRoute(friend.lat, friend.lng, friend.name, showMarker: false);
        break;
      }
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
        // Slightly away from user (northeast)
        lat: centerLat + 0.003,
        lng: centerLng + 0.004,
        color: Colors.orange,
      ),
    ];

    for (final friend in _friends) {
      try {
        // Create emoji marker image (balanced size)
        const markerSize = 110;
        final imageData =
            await _createEmojiMarkerImage(friend.emoji, friend.color, markerSize);

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
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(_initialLng!, _initialLat!),
              ),
              zoom: 15.0,
            ),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
          ),

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
                          onPressed: () => context.push(Routes.passengerSettings),
                        ),
                        const SizedBox(height: 12),
                        // Recenter Button (Top Right)
                        GlassIconButton(
                          icon: Icons.my_location,
                          iconColor: AppColors.primary,
                          onPressed: _flyToUserLocation,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 3. Draggable Search Sheet (Animated - slides down when route selected)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _isRouteSelected ? -350 : 0,
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
                                    onTap: () =>
                                        context.push(Routes.passengerBooking),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickActionCard(
                                    icon: Icons.business,
                                    label: '公司',
                                    onTap: () {},
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

          // 4. Confirm & Cancel Buttons (Bottom, when route is active)
          if (_isRouteSelected)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Confirm Button (draggable to reveal cancel below)
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _cancelRevealOffset -= details.delta.dy;
                        _cancelRevealOffset = _cancelRevealOffset.clamp(0.0, 80.0);
                        if (_cancelRevealOffset > 40) {
                          _isCancelRevealed = true;
                        }
                      });
                    },
                    onVerticalDragEnd: (details) {
                      setState(() {
                        _cancelRevealOffset = 0;
                      });
                    },
                    onTap: _showVehicleSelectionSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      transform: Matrix4.translationValues(0, -_cancelRevealOffset * 0.5, 0),
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.dividerDark,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '確認叫車',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selectedDestinationName != null)
                              Text(
                                _selectedDestinationName!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Cancel Button (revealed BELOW confirm by dragging up)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isCancelRevealed ? 68 : 0,
                    child: _isCancelRevealed
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _isCancelRevealed = false);
                                _clearRoute();
                              },
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    '取消',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Drag hint
                  if (!_isCancelRevealed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '↑ 上滑取消',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Show vehicle selection bottom sheet
  void _showVehicleSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildVehicleSelectionSheet(),
    );
  }

<<<<<<< Updated upstream
=======
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

>>>>>>> Stashed changes
  /// Build vehicle selection sheet content
  Widget _buildVehicleSelectionSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          const SizedBox(height: 20),

          // Title
          const Text(
            '選擇車型',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle Options
          Expanded(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildVehicleOption(
                      name: '元氣汪汪',
                      emoji: '🐕',
                      price: 'NT\$120',
                      time: '3 分鐘',
                      isSelected: _selectedVehicleIndex == 0,
                      onTap: () => setSheetState(() => _selectedVehicleIndex = 0),
                    ),
                    _buildVehicleOption(
                      name: '招財貓貓',
                      emoji: '🐱',
                      price: 'NT\$150',
                      time: '5 分鐘',
                      isSelected: _selectedVehicleIndex == 1,
                      onTap: () => setSheetState(() => _selectedVehicleIndex = 1),
                    ),
                    _buildVehicleOption(
                      name: '北極熊阿北',
                      emoji: '🐻‍❄️',
                      price: 'NT\$200',
                      time: '8 分鐘',
                      isSelected: _selectedVehicleIndex == 2,
                      onTap: () => setSheetState(() => _selectedVehicleIndex = 2),
                    ),
                  ],
                );
              },
            ),
          ),

          // Confirm Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: GestureDetector(
              onTap: () {
<<<<<<< Updated upstream
                Navigator.pop(context);
                // Navigate to waiting for driver page with location data
=======
                final priceDog = _calculatePrice('元氣汪汪');
                final priceCat = _calculatePrice('招財貓貓');
                final priceBear = _calculatePrice('北極熊阿北');

                Navigator.pop(context);

                // Navigate to waiting page
>>>>>>> Stashed changes
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
                    'vehicleType': ['元氣汪汪', '招財貓貓', '北極熊阿北'][_selectedVehicleIndex],
                    'price': [120, 150, 200][_selectedVehicleIndex],
                  },
                );
<<<<<<< Updated upstream
=======

                // IMMEDIATELY reset home page state
                // This ensures that whether we return via pop or GoRouter, the state is clean.
                _clearRoute();
>>>>>>> Stashed changes
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
          ),
        ],
      ),
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

          // Price
          Text(
            price,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
        onTap: () => _drawNavigationRoute(lat, lng, address),
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
        debugPrint(
            'Route: ${(routeResult.distanceMeters / 1000).toStringAsFixed(1)}km, '
            '${(routeResult.durationSeconds / 60).toStringAsFixed(0)}min');
      } else {
        // Fallback to straight line if API fails
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
        ),
        MapAnimationOptions(duration: 1500),
      );

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

  /// Clear route and reset to search mode
  Future<void> _clearRoute() async {
    const sourceId = 'route-source';
    const emptyGeoJson = '{"type":"Feature","geometry":{"type":"LineString","coordinates":[]}}';

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

      // Reset state
      setState(() {
        _isRouteSelected = false;
        _selectedDestinationName = null;
        _selectedDestLat = null;
        _selectedDestLng = null;
      });

      // Return camera to user location
      if (_initialLat != null && _initialLng != null) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(_initialLng!, _initialLat!),
            ),
            zoom: 15.0,
          ),
          MapAnimationOptions(duration: 1000),
        );
      }
    } catch (e) {
      debugPrint('Failed to clear route: $e');
    }
  }

  /// Handle search submission - real Mapbox geocoding
  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;

    _searchFocusNode.unfocus();

    setState(() => _isSearching = true);

    try {
      // Real geocoding via Mapbox API
      final result = await MapboxApiService.getCoordinates(query);

      if (result != null) {
        _searchController.clear();
        await _drawNavigationRoute(
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
