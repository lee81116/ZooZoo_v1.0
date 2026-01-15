import 'package:flutter/material.dart';

import '../../../settings/presentation/pages/passenger_settings_page.dart';
import '../../../store/presentation/pages/store_page.dart';
import 'passenger_home_page.dart';

/// Main container for passenger app with PageView
class PassengerMainPage extends StatefulWidget {
  const PassengerMainPage({super.key});

  @override
  State<PassengerMainPage> createState() => _PassengerMainPageState();
}

class _PassengerMainPageState extends State<PassengerMainPage> {
  late PageController _pageController;
  int _currentPage = 1;

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
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: const [
              StorePage(),
              PassengerHomePage(),
              PassengerSettingsPage(),
            ],
          ),
          Positioned(
            bottom: 20,
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
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.9)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
