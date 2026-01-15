import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Widget shown when driver is online and waiting for orders
class WaitingForOrder extends StatefulWidget {
  final DateTime onlineSince;
  final int todayTrips;
  final int todayEarnings;
  final VoidCallback onGoOffline;

  const WaitingForOrder({
    super.key,
    required this.onlineSince,
    required this.todayTrips,
    required this.todayEarnings,
    required this.onGoOffline,
  });

  @override
  State<WaitingForOrder> createState() => _WaitingForOrderState();
}

class _WaitingForOrderState extends State<WaitingForOrder>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Duration _waitingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    // Update waiting time every second
    _updateWaitingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateWaitingTime();
    });

    // Pulsing animation for the waiting indicator
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  void _updateWaitingTime() {
    setState(() {
      _waitingTime = DateTime.now().difference(widget.onlineSince);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        
        // Animated waiting indicator
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: const Center(
              child: Text(
                '🐱',
                style: TextStyle(fontSize: 72),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Status text
        const Text(
          '等待訂單中...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Waiting time
        Text(
          '已等待 ${_formatDuration(_waitingTime)}',
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.textSecondary,
          ),
        ),
        
        const SizedBox(height: 48),
        
        // Today's stats
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.local_taxi,
                value: '${widget.todayTrips}',
                label: '今日趟數',
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.divider,
              ),
              _buildStatItem(
                icon: Icons.attach_money,
                value: '\$${widget.todayEarnings}',
                label: '今日收入',
              ),
            ],
          ),
        ),
        
        const Spacer(flex: 3),
        
        // Go offline button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: widget.onGoOffline,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '下線休息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
