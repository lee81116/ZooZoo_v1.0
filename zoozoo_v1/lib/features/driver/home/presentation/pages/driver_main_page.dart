import 'package:flutter/material.dart';

import '../../../history/presentation/pages/driver_history_page.dart';
import '../../../settings/presentation/pages/driver_settings_page.dart';
import 'driver_home_page.dart';

/// Driver main container with swipeable pages
/// Structure: [History] <-> [Home] <-> [Settings]
class DriverMainPage extends StatefulWidget {
  const DriverMainPage({super.key});

  @override
  State<DriverMainPage> createState() => _DriverMainPageState();
}

class _DriverMainPageState extends State<DriverMainPage> {
  late final PageController _pageController;
  int _currentPage = 1; // Start at Home (middle)

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Swipeable pages
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              DriverHistoryPage(),    // Left: History
              DriverHomePage(),       // Center: Home
              DriverSettingsPage(),   // Right: Settings
            ],
          ),
          // Page indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive 
                ? Colors.white 
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
