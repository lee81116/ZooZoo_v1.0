import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/passenger/home/presentation/pages/passenger_main_page.dart';
import '../../features/passenger/home/presentation/pages/passenger_3d_map_page.dart';
import '../../core/services/map/map_models.dart';
import '../../features/passenger/booking/presentation/pages/booking_map_page.dart';
import '../../features/passenger/booking/presentation/pages/booking_map_page.dart';
import '../../features/driver/home/presentation/pages/driver_main_page.dart';
import '../../features/driver/financial/presentation/pages/financial_planner_page.dart';

/// Route path constants
abstract class Routes {
  static const String splash = '/';
  static const String login = '/login';
  static const String passengerRegister = '/register/passenger';
  static const String driverRegister = '/register/driver';
  static const String passengerHome = '/passenger';
  static const String passengerBooking = '/passenger/booking';
  static const String passenger3DMap = '/passenger/3d-map';
  static const String driverHome = '/driver';
  static const String financialPlanner = '/driver/financial';
}

/// App router configuration
final appRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  routes: [
    // Splash - entry point
    GoRoute(
      path: Routes.splash,
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),

    // Login
    GoRoute(
      path: Routes.login,
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    // Passenger Register (placeholder)
    GoRoute(
      path: Routes.passengerRegister,
      name: 'passengerRegister',
      builder: (context, state) => const _PlaceholderPage(title: '乘客註冊'),
    ),

    // Driver Register (placeholder)
    GoRoute(
      path: Routes.driverRegister,
      name: 'driverRegister',
      builder: (context, state) => const _PlaceholderPage(title: '司機註冊'),
    ),

    // Passenger Home - with swipeable pages
    GoRoute(
      path: Routes.passengerHome,
      name: 'passengerHome',
      builder: (context, state) => const PassengerMainPage(),
    ),

    // Passenger Booking - map and vehicle selection
    GoRoute(
      path: Routes.passengerBooking,
      name: 'passengerBooking',
      builder: (context, state) => const BookingMapPage(),
    ),

    // Passenger 3D Map with simulation
    GoRoute(
      path: Routes.passenger3DMap,
      name: 'passenger3DMap',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return Passenger3DMapPage(
          startLocation: extra?['startLocation'] as AppLatLng?,
          endLocation: extra?['endLocation'] as AppLatLng?,
          vehicleType: extra?['vehicleType'] as String?,
          price: extra?['price'] as int?,
        );
      },
    ),

    // Driver Home - with swipeable pages
    GoRoute(
      path: Routes.driverHome,
      name: 'driverHome',
      builder: (context, state) => const DriverMainPage(),
    ),

    // Driver Financial Planner
    GoRoute(
      path: Routes.financialPlanner,
      name: 'financialPlanner',
      builder: (context, state) => const FinancialPlannerPage(),
    ),
  ],

  // Error page
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);

/// Temporary placeholder page for unimplemented routes
class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '$title\n(開發中)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
