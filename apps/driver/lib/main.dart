import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'home_page.dart';

// The entry point of the application.
// 應用程式的進入點。
void main() {
  runApp(const DriverApp());
}

// The root widget of the Driver application.
// 司機端應用程式的根組件。
class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider is used to provide state management down the widget tree.
    // MultiProvider 用於將狀態管理向下傳遞給組件樹。
    return MultiProvider(
      providers: [
        // Initialize the DriverStatusProvider to manage driver's online/offline state.
        // 初始化 DriverStatusProvider 以管理司機的上線/下線狀態。
        ChangeNotifierProvider(create: (_) => DriverStatusProvider()),
      ],
      child: MaterialApp(
        title: 'ZooZoo Driver',
        // Configure the app's theme with Material 3 design using custom MaterialTheme.
        // 使用自訂的 MaterialTheme 配置應用程式的主題（Material 3 設計）。
        theme: MaterialTheme(TextTheme()).light(),
        
        // Dark theme configuration.
        // 深色主題配置。
        darkTheme: MaterialTheme(TextTheme()).dark(),
        
        // Set the home page of the app.
        // 設定應用程式的首頁。
        home: const DriverHomePage(),
      ),
    );
  }
}

// A Provider class to manage the driver's global status (Online/Offline) and service modes.
// 一個 Provider 類別，用於管理司機的全局狀態（上線/下線）和服務模式。
class DriverStatusProvider extends ChangeNotifier {
  // Internal variable to store online status, default is false.
  // 內部變數，用於儲存上線狀態，預設為 false。
  bool _isOnline = false;

  // Internal variable to store the current mode snippet or status (placeholder).
  // 內部變數，用於儲存當前模式片段或狀態（佔位符）。
  String _mode = 'Standard'; 

  // Getter to access the online status.
  // 用於存取上線狀態的 Getter。
  bool get isOnline => _isOnline;

  // Getter to access the current mode.
  // 用於存取當前模式的 Getter。
  String get mode => _mode;

  // Method to update the online status and notify listeners (UI).
  // 用於更新上線狀態並通知監聽者（UI）的方法。
  void setOnline(bool value) {
    _isOnline = value;
    // Notify all widgets listening to this provider to rebuild.
    // 通知所有監聽此 provider 的組件重新建構。
    notifyListeners();
  }
  
  // Method to update the service mode.
  // 用於更新服務模式的方法。
  void setMode(String newMode) {
    _mode = newMode;
    notifyListeners();
  }
}
