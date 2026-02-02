import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/glass_button.dart';
import '../../../../../shared/widgets/parallax_background.dart';
import '../../bloc/driver_bloc.dart';
import '../widgets/driver_top_bar.dart';
import '../widgets/driver_profile_sheet.dart';

class DriverOfflineView extends StatelessWidget {
  const DriverOfflineView({super.key});

  @override
  Widget build(BuildContext context) {
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
              DriverTopBar(
                isOnline: false,
                onProfileTap: () => _showProfilePage(context),
              ),
              const Spacer(),
              _buildOfflineContent(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
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

  Widget _buildOfflineContent(BuildContext context) {
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

  void _showProfilePage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const DriverProfileSheet(),
    );
  }
}
