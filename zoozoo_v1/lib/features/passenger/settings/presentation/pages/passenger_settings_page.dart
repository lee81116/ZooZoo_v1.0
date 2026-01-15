import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';

/// Passenger settings page - placeholder
class PassengerSettingsPage extends StatelessWidget {
  const PassengerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_back_ios, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('首頁', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    '設定',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildSettingsItem(icon: Icons.person_outline, title: '個人資料', onTap: () {}),
                  _buildSettingsItem(icon: Icons.payment_outlined, title: '付款方式', onTap: () {}),
                  _buildSettingsItem(icon: Icons.notifications_outlined, title: '通知設定', onTap: () {}),
                  _buildSettingsItem(icon: Icons.help_outline, title: '幫助中心', onTap: () {}),
                  _buildSettingsItem(icon: Icons.info_outline, title: '關於我們', onTap: () {}),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('登出'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textHint),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
