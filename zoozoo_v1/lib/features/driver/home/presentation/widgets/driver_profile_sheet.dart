import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/driver_bloc.dart';

class DriverProfileSheet extends StatelessWidget {
  const DriverProfileSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
