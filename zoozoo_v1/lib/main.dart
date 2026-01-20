import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for zh_TW
  await initializeDateFormatting('zh_TW', null);

  // Configure Mapbox public access token
  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjU1MTJhMGN5bjNlczc1Y2o2OWpsNCJ9.KG88KmWjysp0PNFO5LCZ1g',
  );

  runApp(const ZooZooApp());
}

/// Global theme mode notifier
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// ZooZoo App root widget
class ZooZooApp extends StatelessWidget {
  const ZooZooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: 'ZooZoo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
