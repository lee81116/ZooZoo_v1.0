import 'package:flutter/material.dart';

import 'app/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
