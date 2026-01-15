import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// User avatar with name, glass style
class UserAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.glassOverlay,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  backgroundImage: avatarUrl != null 
                      ? NetworkImage(avatarUrl!) 
                      : null,
                  child: avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                // Name
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                // Arrow indicator
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
