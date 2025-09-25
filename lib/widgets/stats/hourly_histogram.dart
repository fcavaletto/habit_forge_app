import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../utils/constants.dart';
import 'time_range_selector.dart';

/// Hourly Completion Histogram Widget
///
/// Displays a bar chart showing the distribution of habit completions
/// throughout the day (0-23 hours) with percentage-based heights.
/// 
/// Features:
/// - 24 bars representing each hour of the day
/// - Percentage-based bar heights
/// - Hour labels in 12-hour format (12 AM, 1 AM, etc.)
/// - Tooltips showing exact count and percentage
/// - Responsive design for different screen sizes
/// - Gradient colors based on completion frequency
class HourlyHistogram extends StatelessWidget {
  final HourlyHistogramData data;
  final ValueChanged<String>? onTimeRangeChanged;

  const HourlyHistogram({
    super.key,
    required this.data,
    this.onTimeRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and time range
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Completions throughout the day',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onTimeRangeChanged != null)
                  TextButton(
                    onPressed: () => _showTimeRangeSelector(context),
                    child: Text(
                      data.formattedTimeRange,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Histogram content
            if (data.hasData) ...[
              _buildHistogram(context),
              const SizedBox(height: 8),
              _buildSummary(context),
            ] else ...[
              _buildEmptyState(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistogram(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxPercentage = data.maxPercentage;
    
    return SizedBox(
      height: 120,
      child: Column(
        children: [
          // Histogram bars
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(24, (hour) {
                final percentage = data.hourlyPercentages[hour]!;
                final count = data.hourlyCompletions[hour]!;
                final isPeakHour = hour == data.peakHour;
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Tooltip(
                      message: _buildTooltipMessage(hour, count, percentage),
                      child: GestureDetector(
                        onTap: () {
                          _showHourDetails(context, hour, count, percentage);
                        },
                        child: Container(
                          height: maxPercentage > 0 ? (percentage / maxPercentage * 100) : 0,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: _getBarColors(colorScheme, percentage, isPeakHour),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          // Horizontal axis with ticks and labels
          _buildHorizontalAxis(context),
        ],
      ),
    );
  }

  /// Build horizontal axis with ticks and labels
  Widget _buildHorizontalAxis(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Define the 5 labels: 0, 6, 12, 18, 24
    final labelHours = [0, 6, 12, 18, 24];
    
    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          // Horizontal line
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          // Ticks and labels
          Row(
            children: List.generate(25, (hour) {
              final isLabelHour = labelHours.contains(hour);
              
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Tick mark
                    Container(
                      height: isLabelHour ? 6 : 3,
                      width: 1,
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 1),
                    // Label (only for specified hours)
                    if (isLabelHour)
                      Text(
                        hour == 24 ? '24' : hour.toString(),
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final peakHour = HourlyHistogramData.formatHour(data.peakHour);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Peak time: $peakHour',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No completion data for ${data.formattedTimeRange.toLowerCase()}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete your habit to see hourly patterns',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTooltipMessage(int hour, int count, double percentage) {
    final hourLabel = HourlyHistogramData.formatHour(hour);
    final percentageText = (percentage * 100).toStringAsFixed(1);
    
    if (count == 0) {
      return '$hourLabel: No completions';
    } else if (count == 1) {
      return '$hourLabel: 1 completion ($percentageText%)';
    } else {
      return '$hourLabel: $count completions ($percentageText%)';
    }
  }

  List<Color> _getBarColors(ColorScheme colorScheme, double percentage, bool isPeakHour) {
    if (percentage == 0) {
      // Return two identical colors for zero percentage to satisfy LinearGradient requirement
      return [
        colorScheme.surfaceContainerHighest,
        colorScheme.surfaceContainerHighest,
      ];
    }
    
    final baseColor = colorScheme.primary; // Always use primary color
    final intensity = (percentage * 0.8 + 0.2).clamp(0.2, 1.0); // Ensure minimum visibility
    
    return [
      baseColor.withValues(alpha: intensity),
      baseColor.withValues(alpha: intensity * 0.7),
    ];
  }

  void _showHourDetails(BuildContext context, int hour, int count, double percentage) {
    final hourLabel = HourlyHistogramData.formatHour(hour);
    final percentageText = (percentage * 100).toStringAsFixed(1);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$hourLabel Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completions: $count'),
            Text('Percentage: $percentageText%'),
            Text('Time Range: ${data.formattedTimeRange}'),
            if (hour == data.peakHour) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Peak Hour',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTimeRangeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TimeRangeSelector.timeRanges.map((range) {
            return ListTile(
              title: Text(range),
              trailing: data.timeRange == range ? const Icon(Icons.check) : null,
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
