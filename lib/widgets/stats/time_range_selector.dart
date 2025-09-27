import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Time Range Selector Widget
///
/// Provides a segmented control for selecting different time ranges
/// for the hourly completion histogram analysis.
///
/// Available options:
/// - Last 7 Days
/// - Last 30 Days  
/// - Total
class TimeRangeSelector extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const TimeRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  static const List<String> timeRanges = [
    'Last 7 Days',
    'Last 30 Days',
    'Total',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: timeRanges.map((range) {
          final isSelected = selectedRange == range;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onRangeChanged(range),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colorScheme.primary 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: isSelected 
                        ? colorScheme.onPrimary 
                        : colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Alternative dropdown-style time range selector
///
/// Provides a more compact dropdown for selecting time ranges
/// when space is limited.
class TimeRangeDropdown extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const TimeRangeDropdown({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedRange,
          onChanged: (String? newValue) {
            if (newValue != null) {
              onRangeChanged(newValue);
            }
          },
          items: TimeRangeSelector.timeRanges.map((String range) {
            return DropdownMenuItem<String>(
              value: range,
              child: Text(
                range,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}