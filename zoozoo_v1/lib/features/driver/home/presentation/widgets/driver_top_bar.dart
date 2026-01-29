import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class DriverTopBar extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onProfileTap;

  const DriverTopBar({
    super.key,
    required this.isOnline,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
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
}
