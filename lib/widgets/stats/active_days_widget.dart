import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Active Days Widget
///
/// Displays a visual representation of which days of the week
/// a habit is scheduled to be active. Shows 7 boxes in a single
/// row representing Monday through Sunday.
///
/// Features:
/// - Visual shading for active/inactive days
/// - Abbreviated weekday names
/// - Theme-integrated styling
/// - Responsive layout
/// - Proper error handling and logging
///
/// @param frequencyDays Map of weekday keys to active status (1=active, 0=inactive)
class ActiveDaysWidget extends StatelessWidget {
  final Map<String, int> frequencyDays;

  const ActiveDaysWidget({
    super.key,
    required this.frequencyDays,
  });

  /// Default frequency days (all days active)
  static const Map<String, int> defaultFrequencyDays = {
    'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1
  };

  /// Ordered list of weekday keys
  static const List<String> weekdayKeys = [
    'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'
  ];

  /// Display names for weekdays
  static const List<String> weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint('📅 [ActiveDays] Rendering with frequency: $frequencyDays');
    debugPrint('📅 [ActiveDays] Frequency days type: ${frequencyDays.runtimeType}');
    debugPrint('📅 [ActiveDays] Frequency days length: ${frequencyDays.length}');
    
    // Validate and process frequency days
    final processedFrequencyDays = _processFrequencyDays(frequencyDays);
    final activeDays = _getActiveDays(processedFrequencyDays);
    
    debugPrint('📅 [ActiveDays] Processed frequency: $processedFrequencyDays');
    debugPrint('📅 [ActiveDays] Active days: $activeDays');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDaysRow(context, processedFrequencyDays),
          ],
        ),
      ),
    );
  }

  /// Build the row of 7 day boxes
  Widget _buildDaysRow(BuildContext context, Map<String, int> frequencyDays) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: List.generate(7, (index) {
        final dayKey = weekdayKeys[index];
        final dayName = weekdayNames[index];
        final isActive = _isDayActive(dayKey, frequencyDays);
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < 6 ? 8.0 : 0, // Add spacing between boxes, except last
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isActive 
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive 
                    ? colorScheme.primary.withValues(alpha: 0.6)
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Text(
              dayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive 
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Process and validate frequency days data
  Map<String, int> _processFrequencyDays(Map<String, int> frequencyDays) {
    debugPrint('🔍 [ActiveDays] Processing frequency days: $frequencyDays');
    
    // Handle null or empty frequency days
    if (frequencyDays.isEmpty) {
      debugPrint('⚠️ [ActiveDays] Empty frequency days, using defaults');
      return defaultFrequencyDays;
    }

    // Ensure all 7 days are present
    final processedDays = <String, int>{};
    for (final dayKey in weekdayKeys) {
      final value = frequencyDays[dayKey];
      debugPrint('🔍 [ActiveDays] Processing $dayKey: $value');
      
      if (value != null && (value == 0 || value == 1)) {
        processedDays[dayKey] = value;
        debugPrint('✅ [ActiveDays] $dayKey: $value (valid)');
      } else {
        debugPrint('⚠️ [ActiveDays] Invalid value for $dayKey: $value, defaulting to active');
        processedDays[dayKey] = 1; // Default to active
      }
    }

    debugPrint('🔍 [ActiveDays] Final processed days: $processedDays');
    return processedDays;
  }

  /// Get list of active day names
  List<String> _getActiveDays(Map<String, int> frequencyDays) {
    final activeDays = <String>[];
    for (int i = 0; i < weekdayKeys.length; i++) {
      final dayKey = weekdayKeys[i];
      final dayName = weekdayNames[i];
      if (_isDayActive(dayKey, frequencyDays)) {
        activeDays.add(dayName);
      }
    }
    return activeDays;
  }

  /// Check if a specific day is active
  bool _isDayActive(String dayKey, Map<String, int> frequencyDays) {
    return frequencyDays[dayKey] == 1;
  }
}
