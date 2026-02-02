import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../../home/bloc/driver_bloc.dart';

class FinancialPlannerPage extends StatefulWidget {
  const FinancialPlannerPage({super.key});

  @override
  State<FinancialPlannerPage> createState() => _FinancialPlannerPageState();
}

class _FinancialPlannerPageState extends State<FinancialPlannerPage> {
  // Input Controllers
  final TextEditingController _targetNetController = TextEditingController();

  // Costs (Default values as per tip)
  final TextEditingController _leaseController = TextEditingController();
  final TextEditingController _fuelController =
      TextEditingController(text: '8000');
  final TextEditingController _maintenanceController =
      TextEditingController(text: '2000');

  // Toggles
  bool _hasLease = false;
  bool _hasFuel = true;
  bool _hasMaintenance = true;

  // Rest Days (0-3)
  int _restDaysPerWeek = 1;

  // Result
  int _calculatedDailyGross = 0;

  @override
  void initState() {
    super.initState();
    // Re-calculate whenever inputs change
    _targetNetController.addListener(_calculate);
    _leaseController.addListener(_calculate);
    _fuelController.addListener(_calculate);
    _maintenanceController.addListener(_calculate);

    // Initial calculation (or load from storage if we had it persistence)
    // For now, let's pre-fill a reasonable targetNet for demo
    _targetNetController.text = '50000';
  }

  @override
  void dispose() {
    _targetNetController.dispose();
    _leaseController.dispose();
    _fuelController.dispose();
    _maintenanceController.dispose();
    super.dispose();
  }

  void _calculate() {
    final int targetNet = int.tryParse(_targetNetController.text) ?? 0;

    int fixedCosts = 0;
    if (_hasLease) fixedCosts += int.tryParse(_leaseController.text) ?? 0;
    if (_hasFuel) fixedCosts += int.tryParse(_fuelController.text) ?? 0;
    if (_hasMaintenance)
      fixedCosts += int.tryParse(_maintenanceController.text) ?? 0;

    // Logic:
    // Work Days = 30 - (rest * 4.3)
    // Total Revenue Needed = Target Net + Costs
    // Daily Target = Total / Work Days

    final double workDays = 30.0 - (_restDaysPerWeek * 4.3);
    if (workDays <= 0) {
      // Edge case safety
      setState(() => _calculatedDailyGross = 0);
      return;
    }

    final int totalRevenueNeeded = targetNet + fixedCosts;
    final int dailyTarget = (totalRevenueNeeded / workDays).ceil();

    setState(() {
      _calculatedDailyGross = dailyTarget;
    });
  }

  void _savePlan() {
    // 1. Save to Global State (DriverBloc)
    context.read<DriverBloc>().updateDailyGoal(_calculatedDailyGross);

    // 2. Show Encouragement Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface, // White/Dark surface
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryLight,
                child:
                    Icon(Icons.emoji_people, size: 50, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              const Text(
                '計畫已確認！',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              Text(
                '老闆，我們一起朝著月薪 \$${_targetNetController.text} 邁進！',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to Home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('出發！',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Dark Professional Mode
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text('我的財務導航',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _savePlan,
            child: const Text('儲存',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 點擊空白處 收起鍵盤
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Result Card (Preview)
              _buildResultCard(),

              const SizedBox(height: 32),

              // Section 2: Input (Target Net)
              const Text('目標設定',
                  style: TextStyle(color: AppColors.textHint, fontSize: 14)),
              const SizedBox(height: 12),
              _buildNetInput(),

              const SizedBox(height: 32),

              // Section 3: Costs List
              const Text('月成本估算',
                  style: TextStyle(color: AppColors.textHint, fontSize: 14)),
              const SizedBox(height: 12),
              _buildCostItem(
                label: '車租 / 貸款',
                controller: _leaseController,
                isEnabled: _hasLease,
                onToggle: (v) {
                  setState(() => _hasLease = v);
                  _calculate();
                },
              ),
              const SizedBox(height: 12),
              _buildCostItem(
                label: '油資 / 充電預估',
                controller: _fuelController,
                isEnabled: _hasFuel,
                onToggle: (v) {
                  setState(() => _hasFuel = v);
                  _calculate();
                },
              ),
              const SizedBox(height: 12),
              _buildCostItem(
                label: '車輛維修 / 保養',
                controller: _maintenanceController,
                isEnabled: _hasMaintenance,
                onToggle: (v) {
                  setState(() => _hasMaintenance = v);
                  _calculate();
                },
              ),

              const SizedBox(height: 32),

              // Section 4: Rest Days
              const Text('生活節奏 (每週休息)',
                  style: TextStyle(color: AppColors.textHint, fontSize: 14)),
              const SizedBox(height: 12),
              _buildRestDaySelector(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '每日營收目標 (Gross)',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '\$$_calculatedDailyGross',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '要賺到目標純利，您每天需跑出 \$$_calculatedDailyGross',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          // Circular progress simulation (Just a visual decoration for now)
          const SizedBox(height: 20),
          SizedBox(
            height: 4,
            width: 100,
            child: LinearProgressIndicator(
              value: 0.0, // Always 0 as per requirement "currently 0%"
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, // White background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary, width: 1.5), // More visible border
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('\$',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _targetNetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '輸入目標月純利',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 18),
                labelText: '稅後純利 (Net)',
                labelStyle: TextStyle(color: Colors.black87, fontSize: 14),
                floatingLabelBehavior:
                    FloatingLabelBehavior.always, // Keep label always visible
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostItem({
    required String label,
    required TextEditingController controller,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A221C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: isEnabled,
              onChanged: (v) => onToggle(v ?? false),
              activeColor: AppColors.primary,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isEnabled ? Colors.white : Colors.grey,
                fontSize: 16,
                fontWeight: isEnabled ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (isEnabled)
            SizedBox(
              width: 100,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: AppColors.warning, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '\$',
                  prefixStyle: const TextStyle(color: AppColors.warning),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.grey.withOpacity(0.5))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.warning)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestDaySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final days = index; // 0, 1, 2, 3
        final isSelected = _restDaysPerWeek == days;
        return GestureDetector(
          onTap: () {
            setState(() => _restDaysPerWeek = days);
            _calculate();
          },
          child: Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : const Color(0xFF2A221C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$days 天',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '休假',
                  style: TextStyle(
                    color: isSelected ? Colors.white70 : Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
