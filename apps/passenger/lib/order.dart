import 'package:flutter/material.dart';

// The Order Page for the Passenger application.
// 乘客端的下單頁面。
class PassengerOrderPage extends StatefulWidget {
  const PassengerOrderPage({super.key});

  @override
  State<PassengerOrderPage> createState() => _PassengerOrderPageState();
}

class _PassengerOrderPageState extends State<PassengerOrderPage> {
  // --- Service Modes State ---
  // --- 服務模式狀態 ---

  // "Rush" and "Comfort" are mutually exclusive for passengers.
  // "幫我趕一下" 與 "舒適" 對於乘客來說是互斥的。
  bool _isRush = false;
  bool _isComfort = false;
  
  // "Quiet" and "Pet" can be combined with others.
  // "安靜" 與 "寵物" 可以與其他模式組合。
  bool _isQuiet = false;
  bool _isPet = false;

  // Show dialog with mode descriptions (Same as Driver).
  // 顯示模式說明的對話框 (與司機端相同)。
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
              Text('幫我趕一下 (Rush):', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('在安全的駕駛行為下盡量最快的抵達目的地，可以接受較低標準的乘車平穩度。'),
              SizedBox(height: 12),
              
              Text('舒適 (Comfort):', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('請遵守-緩步加減速，加速時以不聽到引擎聲為基準，減速時請提前輕踩煞車緩步減速。行駛過程盡量保持定油門，勿頻繁踩、放油門，盡量不點煞急煞。'),
              SizedBox(height: 12),
              
              Text('安靜 (Quiet):', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('請遵守-關閉車窗，關閉車內音樂，盡量關閉導航及測速語音，盡量不按喇叭，行程結束後記得開啟聲音才不會聽不到我們的播報歐!'),
              SizedBox(height: 12),
              
              Text('寵物 (Pet):', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order (預約行程)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             // --- Service Modes Selection ---
             // --- 服務模式選擇 ---
            Row(
              children: [
                const Text(
                  '選擇服務模式 (Service Modes)', 
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
            
            // Checkbox for "Rush" mode. Mutually exclusive with Comfort.
            // "幫我趕一下" 模式。與舒適模式互斥。
            SwitchListTile(
              title: const Text('幫我趕一下 (Rush)'),
              subtitle: const Text('趕時間，可接受較快車速 (Fast)'),
              value: _isRush,
              onChanged: (val) {
                setState(() {
                  _isRush = val;
                  if (_isRush) _isComfort = false; // Disable Comfort if Rush is enabled
                });
              },
            ),
            
            // Checkbox for "Comfort" mode. Mutually exclusive with Rush.
            // "舒適" 模式。與趕一下模式互斥。
            SwitchListTile(
              title: const Text('舒適 (Comfort)'),
              subtitle: const Text('平穩駕駛，不急煞 (Smooth ride)'),
              value: _isComfort,
              onChanged: (val) {
                setState(() {
                  _isComfort = val;
                  if (_isComfort) _isRush = false; // Disable Rush if Comfort is enabled
                });
              },
            ),
            
            // Checkbox for "Quiet" mode.
            // "安靜" 模式。
            SwitchListTile(
              title: const Text('安靜 (Quiet)'),
              subtitle: const Text('不聊天，關閉音樂 (No chat/music)'),
              value: _isQuiet,
              onChanged: (val) => setState(() => _isQuiet = val),
            ),
            
            // Checkbox for "Pet" mode.
            // "寵物" 模式。
            SwitchListTile(
              title: const Text('寵物 (Pet)'),
              subtitle: const Text('攜帶寵物 (Traveling with pets)'),
              value: _isPet,
              onChanged: (val) => setState(() => _isPet = val),
            ),

            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Submit order logic placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order Submitted!')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('確認預約 (Confirm Order)', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
