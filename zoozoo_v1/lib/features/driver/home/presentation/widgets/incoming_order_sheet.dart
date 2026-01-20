import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/theme/app_colors.dart';

/// Bottom sheet shown when a new order comes in
class IncomingOrderSheet extends StatefulWidget {
  final Order order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTimeout;
  final int timeoutSeconds;

  const IncomingOrderSheet({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onTimeout,
    this.timeoutSeconds = 15,
  });

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends State<IncomingOrderSheet>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  late Timer _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds;

    // Play notification sound
    _playNotificationSound();

    // Start countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _timer.cancel();
        widget.onTimeout();
      }

      // Vibrate at 5 seconds remaining
      if (_remainingSeconds == 5) {
        HapticFeedback.heavyImpact();
      }
    });

    // Pulse animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  void _playNotificationSound() {
    // Simple haptic feedback as placeholder for sound
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final progress = _remainingSeconds / widget.timeoutSeconds;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar (countdown)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                _remainingSeconds <= 5 ? AppColors.error : AppColors.primary,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header with countdown
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1 + (_animController.value * 0.1),
                          child: const Text(
                            '🔔',
                            style: TextStyle(fontSize: 32),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '新訂單！',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _remainingSeconds <= 5
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_remainingSeconds 秒',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _remainingSeconds <= 5
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

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
                      // Avatar emoji
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
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${order.passenger.rating.toStringAsFixed(1)} (${order.passenger.totalTrips} 趟)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                      // Pickup
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '上車地點',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  order.pickupAddress,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Dotted line
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Row(
                          children: [
                            Column(
                              children: List.generate(
                                3,
                                (_) => Container(
                                  width: 2,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  color: AppColors.divider,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Destination
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flag,
                              color: AppColors.accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '目的地',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  order.destinationAddress,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Price and vehicle info
                Row(
                  children: [
                    // Vehicle type
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Text(
                              order.vehicleEmoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.vehicleType,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        '\$${order.price}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Distance and time
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.route,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${order.distance.toStringAsFixed(1)} 公里',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '約 ${order.estimatedMinutes} 分鐘',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Reject button
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: widget.onReject,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '拒絕',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Accept button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: widget.onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '接單',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
