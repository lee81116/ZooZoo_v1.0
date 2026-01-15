import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../main.dart';

/// Login page - authentication entry
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handle login with test accounts
  void _handleLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _errorMessage = null);

    // Test account: 00/00 -> Passenger
    if (email == '00' && password == '00') {
      context.go(Routes.passengerHome);
      return;
    }

    // Test account: 01/01 -> Driver
    if (email == '01' && password == '01') {
      context.go(Routes.driverHome);
      return;
    }

    // Invalid credentials
    setState(() => _errorMessage = '帳號或密碼錯誤');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              _buildThemeToggle(isDark),
              const SizedBox(height: 40),
              _buildHeader(isDark),
              const SizedBox(height: 48),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _buildErrorMessage(),
              ],
              const SizedBox(height: 24),
              _buildLoginButton(),
              const SizedBox(height: 16),
              _buildRegisterLinks(isDark),
              const Spacer(),
              _buildTestAccountHint(isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          isDark ? '深色模式' : '淺色模式',
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 60,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.divider,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '歡迎回來',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '登入以繼續您的旅程',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: const InputDecoration(
        hintText: '電子郵件',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      onSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        hintText: '密碼',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      onSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildErrorMessage() {
    return Text(
      _errorMessage!,
      style: const TextStyle(
        color: AppColors.error,
        fontSize: 14,
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _handleLogin,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('登入'),
      ),
    );
  }

  Widget _buildRegisterLinks(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '還沒有帳號？',
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => context.push(Routes.passengerRegister),
          child: const Text('乘客註冊'),
        ),
        Text(
          '/',
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => context.push(Routes.driverRegister),
          child: const Text('司機註冊'),
        ),
      ],
    );
  }

  Widget _buildTestAccountHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '測試帳號',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '乘客：00 / 00\n司機：01 / 01',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
