import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/constants.dart';

/// Completion Chart Widget
///
/// Displays a line chart showing habit completion rates over the last 30 days.
/// Each data point represents either 0% (not completed) or 100% (completed)
/// for accurate daily habit tracking visualization.
class CompletionChart extends StatelessWidget {
  final List<double> completionData;

  const CompletionChart({
    super.key,
    required this.completionData,
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
            Text(
              'Completion Rate (Last ${AppConstants.chartDaysCount} Days)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: AppConstants.chartHeight,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          // Show date labels every 7 days to avoid crowding
                          if (value.toInt() % 7 == 0) {
                            final daysAgo = AppConstants.chartDaysCount - 1 - value.toInt();
                            final date = DateTime.now().subtract(Duration(days: daysAgo));
                            return Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: completionData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
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
                            radius: 3,
                            color: colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: colorScheme.surface,
                          );
                        },
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 1,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final percentage = (spot.y * 100).toInt();
                          final daysAgo = AppConstants.chartDaysCount - 1 - spot.x.toInt();
                          final date = DateTime.now().subtract(Duration(days: daysAgo));

                          return LineTooltipItem(
                            '${date.month}/${date.day}: $percentage%',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
