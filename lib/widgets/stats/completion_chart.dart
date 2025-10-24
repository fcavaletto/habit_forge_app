import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/constants.dart';

/// Completion Chart Widget
///
/// Displays a line chart showing habit completion rates over different time periods.
/// Each data point represents either 0% (not completed) or 100% (completed)
/// for accurate daily habit tracking visualization.
/// 
/// Features:
/// - Time range selection (Last 7 Days, Last 30 Days, Last 365 Days)
/// - Interactive time range selector
/// - Responsive chart with proper padding
/// - Tooltips showing exact completion data
class CompletionChart extends StatelessWidget {
  final List<double> completionData;
  final DateTime currentDate;
  final String timeRange;
  final ValueChanged<String>? onTimeRangeChanged;

  const CompletionChart({
    super.key,
    required this.completionData,
    required this.currentDate,
    required this.timeRange,
    this.onTimeRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and time range selector
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Completion Rates',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onTimeRangeChanged != null)
                  TextButton(
                    onPressed: () => _showTimeRangeSelector(context),
                    child: Text(
                      timeRange,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: AppConstants.chartHeight,
              child: timeRange == 'Last 365 Days' 
                  ? _buildBarChart(context)
                  : _buildLineChart(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Build line chart for 7-day and 30-day ranges
  Widget _buildLineChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 0.2, // Show lines at 20%, 40%, 60%, 80%, 100%
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outline.withValues(alpha: 0.3),
              strokeWidth: 0.5,
            );
          },
          verticalInterval: 1,
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: Colors.transparent,
              strokeWidth: 0,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 0.2, // Show labels at 0%, 20%, 40%, 60%, 80%, 100%
              getTitlesWidget: (value, meta) {
                // Show labels for 0%, 20%, 40%, 60%, 80%, 100%
                // Use tolerance for floating point comparison
                const tolerance = 0.01;
                if ((value - 0.0).abs() < tolerance || 
                    (value - 0.2).abs() < tolerance || 
                    (value - 0.4).abs() < tolerance || 
                    (value - 0.6).abs() < tolerance || 
                    (value - 0.8).abs() < tolerance || 
                    (value - 1.0).abs() < tolerance) {
                  return Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink(); // Hide other labels
              },
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: completionData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value);
            }).toList(),
            isCurved: false,
            color: colorScheme.primary,
            barWidth: AppConstants.chartBarWidth,
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2.5,
                  color: colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
          ),
        ],
        minY: 0,
        maxY: 1.0, // Increased from 1.0 to provide 5% padding above 100%
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final percentage = (spot.y * 100).toInt();
                final daysAgo = completionData.length - 1 - spot.x.toInt();
                final date = currentDate.subtract(Duration(days: daysAgo));

                return LineTooltipItem(
                  '${date.day} ${_getMonthAbbreviation(date.month)}: $percentage%',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// Build bar chart for 365-day range
  Widget _buildBarChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 0.2, // Show lines at 20%, 40%, 60%, 80%, 100%
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.outline.withValues(alpha: 0.3),
              strokeWidth: 0.5,
            );
          },
          verticalInterval: 1,
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: Colors.transparent,
              strokeWidth: 0,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 0.2, // Show labels at 0%, 20%, 40%, 60%, 80%, 100%
              getTitlesWidget: (value, meta) {
                // Show labels for 0%, 20%, 40%, 60%, 80%, 100%
                // Use tolerance for floating point comparison
                const tolerance = 0.01;
                if ((value - 0.0).abs() < tolerance || 
                    (value - 0.2).abs() < tolerance || 
                    (value - 0.4).abs() < tolerance || 
                    (value - 0.6).abs() < tolerance || 
                    (value - 0.8).abs() < tolerance || 
                    (value - 1.0).abs() < tolerance) {
                  return Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink(); // Hide other labels
              },
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        barGroups: completionData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: entry.value > 0 
                    ? colorScheme.primary 
                    : colorScheme.surfaceContainerHighest,
                width: 1.5, // Thinner bars for 365 data points
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ],
          );
        }).toList(),
        minY: 0,
        maxY: 1.05, // Increased from 1.0 to provide 5% padding above 100%
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final percentage = (rod.toY * 100).toInt();
              final daysAgo = completionData.length - 1 - group.x;
              final date = currentDate.subtract(Duration(days: daysAgo));

              return BarTooltipItem(
                '${date.day} ${_getMonthAbbreviation(date.month)}: $percentage%',
                TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Get abbreviated month name from month number
  String _getMonthAbbreviation(int month) {
    const monthAbbreviations = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthAbbreviations[month];
  }

  /// Show time range selector dialog
  void _showTimeRangeSelector(BuildContext context) {
    const timeRanges = AppConstants.completionChartTimeRanges;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: timeRanges.map((range) {
            return ListTile(
              title: Text(range),
              trailing: timeRange == range ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.of(context).pop();
                onTimeRangeChanged?.call(range);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
