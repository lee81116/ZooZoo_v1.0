import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';

class WeeklyEarningsChart extends StatelessWidget {
  final Map<DateTime, int> dailyEarnings;
  final DateTime? selectedDate;
  final Function(DateTime) onDaySelected;
  final DateTime weekStartDate;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToday;
  final int dailyGoal;
  final VoidCallback onEditGoal;

  const WeeklyEarningsChart({
    super.key,
    required this.dailyEarnings,
    required this.selectedDate,
    required this.onDaySelected,
    required this.weekStartDate,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onToday,
    required this.dailyGoal,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method equivalent logic, ensuring imports are safe)
    final sortedKeys = dailyEarnings.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    double maxEarning = 0;
    for (var earning in dailyEarnings.values) {
      if (earning > maxEarning) maxEarning = earning.toDouble();
    }
    // Ensure maxY is at least the dailyGoal + buffer
    final double goalDouble = dailyGoal.toDouble();
    if (goalDouble > maxEarning) maxEarning = goalDouble;

    maxEarning = maxEarning == 0 ? 100 : maxEarning * 1.2;

    // Date Range String: "M/d - M/d"
    final weekEnd = weekStartDate.add(const Duration(days: 6));
    final dateRange =
        '${DateFormat('M/d').format(weekStartDate)} - ${DateFormat('M/d').format(weekEnd)}';

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          // Swift Right -> Previous
          onPreviousWeek();
        } else if (details.primaryVelocity! < 0) {
          // Swipe Left -> Next
          onNextWeek();
        }
      },
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date Range and Today Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onEditGoal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '目標 \$$dailyGoal',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit,
                              size: 12, color: AppColors.textHint),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onToday,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxEarning,
                  barTouchData: BarTouchData(
                    allowTouchBarBackDraw: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.accent,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final date = sortedKeys[group.x.toInt()];
                        final earning = dailyEarnings[date];
                        return BarTooltipItem(
                          '\$$earning',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        return;
                      }
                      if (event is FlTapUpEvent) {
                        final index =
                            barTouchResponse.spot!.touchedBarGroupIndex;
                        if (index >= 0 && index < sortedKeys.length) {
                          onDaySelected(sortedKeys[index]);
                        }
                      }
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= sortedKeys.length) {
                            return const SizedBox();
                          }
                          final date = sortedKeys[value.toInt()];
                          final isSelected = selectedDate != null &&
                              DateUtils.isSameDay(selectedDate, date);

                          // Check if goal reached for this day
                          final earning = dailyEarnings[date] ?? 0;
                          final isGoalReached = earning >= dailyGoal;

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('E', 'zh_TW')
                                      .format(date)
                                      .replaceAll('週', ''),
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isGoalReached)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: AppColors
                                          .warning, // Glowing/Gold color
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: goalDouble,
                        color: AppColors.accent.withOpacity(0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: TextStyle(
                            color: AppColors.accent.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'Goal',
                        ),
                      ),
                    ],
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedKeys.asMap().entries.map((entry) {
                    final index = entry.key;
                    final date = entry.value;
                    final earning = dailyEarnings[date] ?? 0;
                    final isSelected = selectedDate != null &&
                        DateUtils.isSameDay(selectedDate, date);

                    final isGoalReached = earning >= dailyGoal;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: earning.toDouble(),
                          color: isGoalReached
                              ? AppColors
                                  .warning // Glowing/Gold color if goal reached
                              : (isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.3)),
                          width: 30,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: goalDouble, // Background is the Goal Height
                            color: AppColors.backgroundSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
