import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
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

  @override
  State<DriverWaitingView> createState() => _DriverWaitingViewState();
}

class _DriverWaitingViewState extends State<DriverWaitingView> {
  MapboxMap? _mapboxMap;

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
                _buildFloatingTopBar(widget.state),
                const Spacer(),
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
        _centerCameraOnUser();
      },
    );
  }

  Future<void> _centerCameraOnUser() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;
      _mapboxMap?.setCamera(CameraOptions(
        center: Point(coordinates: Position(position.longitude, position.latitude)),
        zoom: 15.0,
      ));
    } catch (e) {
      debugPrint('Error centering map: $e');
    }
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
                   _showSnackBar(context, '已下線休息');
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
