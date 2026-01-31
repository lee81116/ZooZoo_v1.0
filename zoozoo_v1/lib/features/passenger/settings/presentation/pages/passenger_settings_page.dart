import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../core/theme/app_colors.dart';

/// Passenger settings page
class PassengerSettingsPage extends StatelessWidget {
  const PassengerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                '設定',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 48),
              // Settings options
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildSettingItem(
                      icon: Icons.person_outline,
                      title: '個人資料',
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.payment_outlined,
                      title: '付款方式',
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.notifications_outlined,
                      title: '通知設定',
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.history,
                      title: '搭乘紀錄',
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.help_outline,
                      title: '幫助中心',
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.info_outline,
                      title: '關於我們',
                      onTap: () {},
                    ),
                    const Divider(height: 32),
                    _buildSettingItem(
                      icon: Icons.logout,
                      title: '登出',
                      isDestructive: true,
                      onTap: () => _handleLogout(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 16,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(Routes.login);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }
}
