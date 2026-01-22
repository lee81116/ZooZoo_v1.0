import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification/notification_service.dart';
import 'features/driver/notifications/voice_reply_dialog.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for zh_TW
  await initializeDateFormatting('zh_TW', null);

  // Configure Mapbox public access token
  try {
    MapboxOptions.setAccessToken(
      'pk.eyJ1IjoibGVlODExMTYiLCJhIjoiY21rZjU1MTJhMGN5bjNlczc1Y2o2OWpsNCJ9.KG88KmWjysp0PNFO5LCZ1g',
    );
  } catch (e) {
    debugPrint('Mapbox not supported on this platform: $e');
  }

  runApp(const ZooZooApp());
}

/// Global theme mode notifier
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// ZooZoo App root widget
class ZooZooApp extends StatefulWidget {
  const ZooZooApp({super.key});

  @override
  State<ZooZooApp> createState() => _ZooZooAppState();
}

class _ZooZooAppState extends State<ZooZooApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final notificationService = NotificationService();
    await notificationService.init();
    
    notificationService.onVoiceReplyRequested.listen((actionId) {
      if (actionId == NotificationService.voiceReplyActionId && mounted) {
        _showVoiceReplyDialog();
      }
    });
  }

  void _showVoiceReplyDialog() {
    // We need a context to show the dialog. 
    // Since we are at the root, we might not have a Navigator context yet if using router directly.
    // However, we can use the appRouter's navigatorKey or context if available.
    // A simple hack for global dialogs is using the router's navigator key.
    
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VoiceReplyDialog(
          onDismiss: () {
            debugPrint("Voice reply dialog dismissed");
          },
        ),
      );
    }
  }

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
