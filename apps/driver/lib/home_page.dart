import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // Import for access to DriverStatusProvider // 匯入以存取 DriverStatusProvider

// The main screen for the driver, showing status and controls.
// 司機的主畫面，顯示狀態和控制選項。
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

// The state class for DriverHomePage, utilizing WidgetsBindingObserver for app lifecycle events.
// DriverHomePage 的狀態類別，使用 WidgetsBindingObserver 來監聽應用程式生命週期事件。
class _DriverHomePageState extends State<DriverHomePage> with WidgetsBindingObserver {
  // State variables for the service modes checkboxes.
  // 服務模式核取方塊的狀態變數。
  
  // "Rush" mode: Help me rush a bit.
  // "幫我趕一下" 模式。
  bool _isRush = false;
  
  // "Comfort" mode: Comfortable ride.
  // "舒適" 模式。
  bool _isComfort = false;

  // "Quiet" mode: Quiet ride.
  // "安靜" 模式。
  bool _isQuiet = false;
  
  // "Pet" mode: Pet-friendly ride.
  // "寵物" 模式。
  bool _isPet = false;

  @override
  void initState() {
    super.initState();
    // Register this object as an observer to app lifecycle changes.
    // 將此物件註冊為應用程式生命週期變化的觀察者。
    WidgetsBinding.instance.addObserver(this);
    
    // Requirement: Automatically go Online when the app opens.
    // 需求：每次開啟應用程式時自動上線。
    // We use addPostFrameCallback to ensure the context is available for the Provider.
    // 我們使用 addPostFrameCallback 確保 context 對 Provider 可用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverStatusProvider>().setOnline(true);
    });
  }

  @override
  void dispose() {
    // Remove the observer when the widget is disposed to prevent memory leaks.
    // 當組件銷毀時移除觀察者以防止記憶體洩漏。
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app lifecycle state changes (e.g., app goes to background).
  // 處理應用程式生命週期狀態的改變（例如：應用程式進入背景）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Requirement: "Slide away to automatically enter background mode".
    // 需求："滑掉自動進背景模式"。
    // In Flutter, standard OS behavior handles caching when minimized.
    // Default lifecycle handling is sufficient for "background mode" unless specific logic is needed.
    // 在 Flutter 中，標準作業系統行為會在最小化時處理快取。除非需要特定邏輯，否則預設的生命週期處理對於 "背景模式" 已經足夠。
    print('App Lifecycle State changed to: $state'); // 應用程式生命週期狀態改變為：$state
  }

  @override
  Widget build(BuildContext context) {
    // Watch the DriverStatusProvider to rebuild UI when status changes.
    // 監聽 DriverStatusProvider 以在狀態改變時重新建構 UI。
    final statusProvider = context.watch<DriverStatusProvider>();
    final isOnline = statusProvider.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Home'), // Title of the page // 頁面標題
        actions: [
          // Settings button in the top right corner.
          // 右上角的設定按鈕。
           IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Placeholder for Settings functionality.
              // 設定功能的佔位符。
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings clicked')), // Settings clicked // 點擊了設定
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Status Indicator UI ---
            // --- 狀態指示器 UI ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                // Change background color based on online status (Green for Online).
                // 根據上線狀態改變背景顏色（上線為綠色）。
                color: isOnline ? Colors.green.shade100 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isOnline ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: Text(
                // Display text based on status.
                // 根據狀態顯示文字。
                isOnline ? 'ONLINE (接單中)' : 'OFFLINE (休息中)',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? Colors.green.shade800 : Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- Online/Offline Toggle Button ---
            // --- 上線/下線 切換按鈕 ---
            ElevatedButton.icon(
              onPressed: () {
                 // Toggle the online status using the provider.
                 // 使用 provider 切換上線狀態。
                 if (isOnline) {
                   statusProvider.setOnline(false); // Go Offline // 下線
                 } else {
                   statusProvider.setOnline(true);  // Go Online // 上線
                 }
              },
              icon: Icon(isOnline ? Icons.power_settings_new : Icons.play_arrow),
              label: Text(isOnline ? 'Go Offline (下線)' : 'Go Online (上線)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                // Change button color based on action (Red for Stop, Green for Start).
                // 根據動作改變按鈕顏色（紅色為停止，綠色為開始）。
                backgroundColor: isOnline ? Colors.red.shade100 : Colors.green.shade100,
                foregroundColor: isOnline ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 40),

            // --- Service Modes Selection ---
            // --- 服務模式選擇 ---
            // --- Service Modes Selection ---
            // --- 服務模式選擇 ---
            Row(
              children: [
                const SizedBox(width: 16),
                const Text(
                  '服務模式 (Service Modes)', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded),
                  color: Colors.grey,
                  onPressed: () => _showModeHelp(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Checkbox for "Rush" mode.
            // "幫我趕一下" 模式的核取方塊。
            SwitchListTile(
              title: const Text('幫我趕一下 (Rush)'),
              value: _isRush,
              onChanged: (val) {
                setState(() {
                  _isRush = val;
                  // Driver can accept multiple types, no mutual exclusion here.
                });
              },
            ),
            
            // Checkbox for "Comfort" mode.
            // "舒適" 模式的核取方塊。
            SwitchListTile(
              title: const Text('舒適 (Comfort)'),
              value: _isComfort,
              onChanged: (val) {
                setState(() {
                  _isComfort = val;
                  // Driver can accept multiple types, no mutual exclusion here.
                });
              },
            ),
            
            // Checkbox for "Quiet" mode.
            // "安靜" 模式的核取方塊。
            SwitchListTile(
              title: const Text('安靜 (Quiet)'),
              value: _isQuiet,
              onChanged: (val) => setState(() => _isQuiet = val),
            ),
            
            // Checkbox for "Pet" mode.
            // "寵物" 模式的核取方塊。
            SwitchListTile(
              title: const Text('寵物 (Pet)'),
              value: _isPet,
              onChanged: (val) => setState(() => _isPet = val),
            ),

            const Spacer(),
            
            // --- Bottom Navigation Buttons ---
            // --- 底部導覽按鈕 ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   // Background Mode Button (Placeholder).
                   // 背景模式按鈕（佔位符）。
                   OutlinedButton.icon(
                    onPressed: () {
                      // Requirement: Manual Background Mode button if needed.
                      // 需求：如果需要的話，手動背景模式按鈕。
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched to Background Mode (模擬背景模式)')),
                      );
                    },
                    icon: const Icon(Icons.layers),
                    label: const Text('Background Mode'),
                  ),
                  
                  // History Button (Placeholder).
                  // 歷史紀錄按鈕（佔位符）。
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History clicked (歷史紀錄)')),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  // Show dialog with mode descriptions.
  // 顯示模式說明的對話框。
  void _showModeHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('各模式說明 (Mode Descriptions)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '幫我趕一下 (Rush):', 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('在安全的駕駛行為下盡量最快的抵達目的地，可以接受較低標準的乘車平穩度。'),
              SizedBox(height: 12),
              
              Text(
                '舒適 (Comfort):', 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('請遵守-緩步加減速，加速時以不聽到引擎聲為基準，減速時請提前輕踩煞車緩步減速。行駛過程盡量保持定油門，勿頻繁踩、放油門，盡量不點煞急煞。'),
              SizedBox(height: 12),
              
              Text(
                '安靜 (Quiet):', 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('請遵守-關閉車窗，關閉車內音樂，盡量關閉導航及測速語音，盡量不按喇叭，行程結束後記得開啟聲音才不會聽不到我們的播報歐!'),
              SizedBox(height: 12),
              
              Text(
                '寵物 (Pet):', 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('可接受寵物上車(除一般毛髮外寵物排泄或嘔吐乘客須支付清潔費)。'),
              SizedBox(height: 12),
              
              Divider(),
              Text(
                '註: 除了「幫我趕一下」及「舒適」兩者不能同時選，其他乘客單是可以同時選擇的 (例如: 舒適且安靜)。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('關閉 (Close)'),
          ),
        ],
      ),
    );
  }
}
