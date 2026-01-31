import 'package:flutter/material.dart';
import 'passenger_home_page.dart';

/// Main container for passenger app (Social Map Home)
class PassengerMainPage extends StatelessWidget {
  const PassengerMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Directly return the Home Page (Social Map)
    // Navigation to other pages (Settings, Profile, Booking) is handled via icons/buttons
    return const PassengerHomePage();
  }
}
