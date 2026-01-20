import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/weekly_earnings_chart.dart';
import '../../../../../core/models/driver_order_history.dart';
import '../../../../../core/services/order/order_storage_service.dart';
import '../../../../../core/theme/app_colors.dart';

/// Driver history page - displays completed order history
class DriverHistoryPage extends StatefulWidget {
  const DriverHistoryPage({super.key});

  @override
  State<DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<DriverHistoryPage> {
  final OrderStorageService _storageService = OrderStorageService();
  List<DriverOrderHistory> _history = [];
  bool _isLoading = true;
  
  // Week navigation
  late DateTime _currentWeekStart;
  
  // Data for the chart
  Map<DateTime, int> _dailyEarnings = {};
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize to start of current week (Monday)
    final now = DateTime.now();
    // In Dart, weekday 1 is Monday, 7 is Sunday.
    // We want the start of the week.
    _currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadHistory();
  }

  // Filtered history list based on selection
  List<DriverOrderHistory> get _filteredHistory {
    if (_selectedDate == null) {
      return _history; // Fail-safe
    }
    return _history.where((order) => DateUtils.isSameDay(order.completedAt, _selectedDate)).toList();
  }

  int get _displayedTotalEarnings {
     if (_selectedDate == null) return 0;
     return _dailyEarnings[_selectedDate] ?? 0;
  }
  
  // Calculate earnings for the month of the currently displayed week
  // We use the week's end date to determine the "primary" month if it spans two months, 
  // or just use the start date. Let's use the start date for simplicity.
  int get _currentMonthEarnings {
    final targetMonth = _currentWeekStart.month;
    final targetYear = _currentWeekStart.year;
    
    int total = 0;
    _dailyEarnings.forEach((date, earnings) {
      if (date.year == targetYear && date.month == targetMonth) {
        total += earnings;
      }
    });
    return total;
  }
  
  // Data for the chart for the CURRENTLY VIEWED week
  Map<DateTime, int> get _currentWeekEarnings {
    final Map<DateTime, int> weekData = {};
    for (int i = 0; i < 7; i++) {
      final date = _currentWeekStart.add(Duration(days: i));
      weekData[date] = _dailyEarnings[date] ?? 0;
    }
    return weekData;
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final history = await _storageService.getOrderHistory();
      
      // Process ALL history into daily earnings map
      final Map<DateTime, int> dailyEarnings = {};
      
      for (var order in history) {
        final date = DateTime(
          order.completedAt.year,
          order.completedAt.month,
          order.completedAt.day,
        );
        dailyEarnings[date] = (dailyEarnings[date] ?? 0) + order.price;
      }

      setState(() {
        _history = history;
        _dailyEarnings = dailyEarnings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入失敗: $e')),
        );
      }
    }
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }
  
  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      // Reset selection to the first day of that week? Or keep relative day?
      // Let's reset to Monday of that week for simplicity, or keep null?
      // Apple Health usually keeps the selection if you tap, but if just swiping...
      // Let's select the first day of the new week to avoid confusion
      _selectedDate = _currentWeekStart;
    });
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      _selectedDate = _currentWeekStart;
    });
  }
  
  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
      _selectedDate = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              '歷史明細',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            
            // Monthly Earnings Header
            if (!_isLoading)
              Text(
                '${DateFormat('M', 'zh_TW').format(_currentWeekStart)}月總收益',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            if (!_isLoading)
              Text(
                '¥$_currentMonthEarnings',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Weekly Earnings Chart
            if (!_isLoading)
              SizedBox(
                height: 250,
                child: WeeklyEarningsChart(
                  dailyEarnings: _currentWeekEarnings,
                  selectedDate: _selectedDate,
                  onDaySelected: _onDaySelected,
                  weekStartDate: _currentWeekStart,
                  onPreviousWeek: _previousWeek,
                  onNextWeek: _nextWeek,
                  onToday: _goToToday,
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Selected Day Summary
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MM/dd (E)', 'zh_TW').format(_selectedDate!),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '總計 ¥$_displayedTotalEarnings',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

             const SizedBox(height: 16),

            // History list for selected day
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredHistory.isEmpty
                      ? _buildEmptyState()
                      : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: AppColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '本日無行程',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    // Sort by time descending
    final sortedList = List<DriverOrderHistory>.from(_filteredHistory)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final order = sortedList[index];
        return GestureDetector(
          onTap: () => _showOrderDetails(order),
          child: _OrderHistoryCard(order: order),
        );
      },
    );
  }

  void _showOrderDetails(DriverOrderHistory order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '訂單詳情',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Price
              Text(
                '¥${order.price}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              
              // Info Rows
              _DetailRow(
                icon: Icons.calendar_today,
                label: '時間',
                value: DateFormat('yyyy/MM/dd HH:mm').format(order.completedAt),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.person_outline,
                label: '乘客',
                value: order.passengerName,
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.map,
                label: '距離',
                value: '${order.distance.toStringAsFixed(1)} km',
              ),
              const SizedBox(height: 24),
              
              // Route
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                         const Icon(Icons.circle, size: 12, color: AppColors.primary),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             order.pickupAddress,
                             style: const TextStyle(fontSize: 14),
                           ),
                         ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: SizedBox(
                        height: 20,
                        child: VerticalDivider(
                          color: AppColors.textHint,
                          thickness: 1,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                         const Icon(Icons.circle, size: 12, color: AppColors.accent),
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             order.destinationAddress,
                             style: const TextStyle(fontSize: 14),
                           ),
                         ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '關閉',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textHint),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Order history card widget
class _OrderHistoryCard extends StatelessWidget {
  final DriverOrderHistory order;

  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Time and Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormat.format(order.completedAt),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '¥${order.price}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Route
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 20,
                    color: AppColors.textHint,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.pickupAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      order.destinationAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
