import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/glass_button.dart';
import '../../../../../shared/widgets/parallax_background.dart';
import '../../bloc/driver_bloc.dart';
import '../../data/driver_state.dart';
import '../widgets/incoming_order_sheet.dart';
import '../widgets/waiting_for_order.dart';

/// Driver home page with order management
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  // Access bloc via context, but we need a reference for the listener removal
  DriverBloc? _bloc;
  MapboxMap? _mapboxMap;
  bool _isOrderSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bloc = context.read<DriverBloc>();
      _bloc?.addListener(_onStateChanged);
      _requestLocationPermission();
    });
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  @override
  void dispose() {
    _bloc?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = context.read<DriverBloc>().state;

    // Show order sheet when new order arrives
    if (state.status == DriverStatus.hasOrder && !_isOrderSheetShowing) {
      _showIncomingOrderSheet();
    }

    setState(() {});
  }

  void _showIncomingOrderSheet() {
    final bloc = context.read<DriverBloc>();
    if (bloc.state.currentOrder == null) return;

    _isOrderSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => IncomingOrderSheet(
        order: bloc.state.currentOrder!,
        onAccept: () {
          Navigator.pop(context);
          _isOrderSheetShowing = false;
          bloc.acceptOrder();
          _showSnackBar('已接單！前往接客');
        },
        onReject: () {
          Navigator.pop(context);
          _isOrderSheetShowing = false;
          bloc.rejectOrder();
          _showSnackBar('已拒絕訂單');
        },
        onTimeout: () {
          Navigator.pop(context);
          _isOrderSheetShowing = false;
          bloc.orderTimeout();
          _showSnackBar('訂單已逾時');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for state changes to rebuild UI
    final driverBloc = context.watch<DriverBloc>();
    final state = driverBloc.state;
    final isOnline = state.status != DriverStatus.offline;

    // Show different content based on status
    if (state.status == DriverStatus.online ||
        state.status == DriverStatus.hasOrder) {
      return _buildWaitingScreen(state);
    }

    if (state.status.hasActiveTrip) {
      return _buildTripScreen(state);
    }

    if (state.status == DriverStatus.completed) {
      return _buildCompletedScreen(state);
    }

    // Default: offline screen
    return _buildOfflineScreen();
  }

  /// Offline screen - show background and go online button
  Widget _buildOfflineScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ParallaxBackground(
          imagePath: 'assets/images/driver_home_bg.png',
          maxOffset: 15.0,
        ),
        _buildGradientOverlay(),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(false),
              const Spacer(),
              _buildOfflineContent(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          const Text(
            '🌙',
            style: TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          const Text(
            '目前離線中',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '準備好了就上線開始接單吧！',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 40),
          GlassButton(
            onPressed: () {
              context.read<DriverBloc>().goOnline();
              _showSnackBar('已上線！等待訂單中...');
            },
            height: 64,
            borderRadius: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_filled,
                  color: AppColors.accent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '上線接單',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Waiting for orders screen (Online Mode)
  Widget _buildWaitingScreen(DriverState state) {
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
                _buildFloatingTopBar(state),
                const Spacer(),
                _buildFloatingBottomPanel(state),
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
        center: Point(coordinates: Position(121.5654, 25.0330)),
        zoom: 15.0,
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
      },
    );
  }

  Widget _buildFloatingTopBar(DriverState state) {
    final double targetAmount = state.dailyEarningsGoal.toDouble();
    final double progress = (state.todayEarnings / targetAmount).clamp(0.0, 1.0);

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
              const Icon(Icons.currency_yen, color: AppColors.warning, size: 20),
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
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, size: 36, color: AppColors.accent),
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
              Icon(Icons.local_fire_department, size: 16, color: AppColors.error),
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
                   _showSnackBar('已下線休息');
                },
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: const [
                      Icon(Icons.power_settings_new, color: AppColors.textSecondary),
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

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trip in progress screen
  Widget _buildTripScreen(DriverState state) {
    final order = state.currentOrder;
    if (order == null) return _buildOfflineScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Status header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            state.status == DriverStatus.toPickup
                                ? Icons.directions_car
                                : state.status == DriverStatus.arrived
                                    ? Icons.person_pin_circle
                                    : Icons.navigation,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.status.displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  state.status == DriverStatus.toPickup
                                      ? '前往 ${order.pickupAddress}'
                                      : state.status == DriverStatus.arrived
                                          ? '等待乘客上車'
                                          : '前往 ${order.destinationAddress}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Passenger info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                order.passenger.avatarEmoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.passenger.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  order.passenger.phone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showSnackBar('撥打電話功能開發中'),
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          _buildRouteRow(
                            icon: Icons.location_on,
                            color: AppColors.primary,
                            label: '上車',
                            address: order.pickupAddress,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Divider(),
                          ),
                          _buildRouteRow(
                            icon: Icons.flag,
                            color: AppColors.accent,
                            label: '目的地',
                            address: order.destinationAddress,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Price
                    Text(
                      '\$${order.price}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      '預估收入',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const Spacer(),

                    // Action button based on status
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state.status == DriverStatus.toPickup) {
                            context.read<DriverBloc>().arrivedAtPickup();
                            _showSnackBar('已到達上車點');
                          } else if (state.status == DriverStatus.arrived) {
                            context.read<DriverBloc>().startTrip();
                            _showSnackBar('行程開始');
                          } else if (state.status == DriverStatus.inTrip) {
                            context.read<DriverBloc>().completeTrip();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          state.status == DriverStatus.toPickup
                              ? '已到達上車點'
                              : state.status == DriverStatus.arrived
                                  ? '乘客已上車'
                                  : '完成行程',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Trip completed screen
  Widget _buildCompletedScreen(DriverState state) {
    final order = state.currentOrder;
    if (order == null) return _buildOfflineScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 80,
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                '行程完成！',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),

              const SizedBox(height: 32),

              // Trip summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '路線',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${order.pickupAddress} → ${order.destinationAddress}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '車型',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Row(
                          children: [
                            Text(order.vehicleEmoji),
                            const SizedBox(width: 8),
                            Text(
                              order.vehicleType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '距離',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${order.distance.toStringAsFixed(1)} 公里',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Earnings
              Text(
                '\$${order.price}',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const Text(
                '收入已入帳',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              // Return button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<DriverBloc>().returnToWaiting();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '繼續接單',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  context.read<DriverBloc>().goOffline();
                },
                child: const Text(
                  '下線休息',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isOnline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showProfilePage(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOnline 
                          ? AppColors.success.withOpacity(0.3)
                          : Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.success : AppColors.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? '上線中' : '離線',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOnline 
                                ? AppColors.success 
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '司機',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? AppColors.success : AppColors.textHint,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? '接單中' : '未接單',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? AppColors.success : AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.5),
          ],
          stops: const [0.0, 0.2, 0.6, 1.0],
        ),
      ),
    );
  }

  void _showProfilePage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.drive_eta, size: 80, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              '司機主頁',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            // const Text('開發中...', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.calculate, color: AppColors.primary),
              ),
              title: const Text('我的財務導航', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('設定目標與成本'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                context.push('/driver/financial');
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<DriverBloc>().goOffline();
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('登出'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
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
