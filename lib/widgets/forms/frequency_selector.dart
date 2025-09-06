import 'package:flutter/material.dart';

/// Frequency selector widget for habit scheduling
///
/// Allows users to select how often they want to perform a habit:
/// - Every Day
/// - Workdays (Mon-Fri)
/// - Weekend (Sat-Sun)
/// - Custom (select specific days)
class FrequencySelector extends StatefulWidget {
  final FrequencyData frequencyData;
  final Function(FrequencyData) onFrequencyChanged;

  const FrequencySelector({
    super.key,
    required this.frequencyData,
    required this.onFrequencyChanged,
  });

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  late FrequencyData _currentFrequency;

  @override
  void initState() {
    super.initState();
    _currentFrequency = widget.frequencyData;
  }

  void _onFrequencyTypeChanged(Frequency newType) {
    setState(() {
      _currentFrequency = FrequencyData.forType(newType);
    });
    widget.onFrequencyChanged(_currentFrequency);
  }

  void _onCustomDayChanged(String day, bool selected) {
    if (_currentFrequency.type == Frequency.custom) {
      setState(() {
        _currentFrequency = _currentFrequency.copyWithDay(day, selected ? 1 : 0);
      });
      widget.onFrequencyChanged(_currentFrequency);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Frequency selection',
      hint: 'Choose how often you want to perform this habit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frequency type selection
          ...Frequency.values.map((frequency) {
            final isSelected = frequency == _currentFrequency.type;
            return Semantics(
              label: '${frequency.displayName} frequency option${isSelected ? ', selected' : ''}',
              hint: frequency.description + (isSelected ? '. Currently selected' : '. Tap to select'),
              button: true,
              selected: isSelected,
              child: GestureDetector(
                onTap: () => _onFrequencyTypeChanged(frequency),
                child: Focus(
                  autofocus: isSelected,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                frequency.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                frequency.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

        // Custom day selection (only shown when Custom is selected)
        if (_currentFrequency.type == Frequency.custom) ...[
          const SizedBox(height: 16),
          Semantics(
            label: 'Select specific days for custom frequency',
            hint: 'Choose which days of the week you want to perform this habit',
            child: const Text(
              'Select days:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((day) {
              final dayName = _getDayDisplayName(day);
              final isSelected = _currentFrequency.days[day] == 1;
              return Semantics(
                label: '$dayName${isSelected ? ', selected' : ', not selected'}',
                hint: isSelected ? 'Tap to remove from selected days' : 'Tap to add to selected days',
                button: true,
                selected: isSelected,
                child: FilterChip(
                  label: Text(dayName),
                  selected: isSelected,
                  onSelected: (selected) => _onCustomDayChanged(day, selected),
                  backgroundColor: Colors.grey[100],
                  selectedColor: Colors.blue[100],
                  checkmarkColor: Colors.blue,
                ),
              );
            }).toList(),
          ),
        ],
      ],
      ),
    );
  }

  String _getDayDisplayName(String day) {
    const dayNames = {
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
    };
    return dayNames[day] ?? day;
  }
}

/// Frequency enum for habit scheduling
enum Frequency {
  everyDay('Every Day', 'Every day'),
  workdays('Workdays', 'Monday to Friday'),
  weekend('Weekend', 'Saturday and Sunday'),
  custom('Custom', 'Select specific days');

  const Frequency(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Data class for frequency configuration
class FrequencyData {
  final Frequency type;
  final Map<String, int> days;

  const FrequencyData(this.type, this.days);

  /// Create frequency data for a given type with appropriate defaults
  factory FrequencyData.forType(Frequency frequencyType) {
    switch (frequencyType) {
      case Frequency.everyDay:
        return FrequencyData(frequencyType, {
          'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1
        });
      case Frequency.workdays:
        return FrequencyData(frequencyType, {
          'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 0, 'sun': 0
        });
      case Frequency.weekend:
        return FrequencyData(frequencyType, {
          'mon': 0, 'tue': 0, 'wed': 0, 'thu': 0, 'fri': 0, 'sat': 1, 'sun': 1
        });
      case Frequency.custom:
        return FrequencyData(frequencyType, {
          'mon': 0, 'tue': 0, 'wed': 0, 'thu': 0, 'fri': 0, 'sat': 0, 'sun': 0
        });
    }
  }

  /// Copy with updated days for custom frequency
  FrequencyData copyWithDay(String day, int value) {
    final newDays = Map<String, int>.from(days);
    newDays[day] = value;
    return FrequencyData(type, newDays);
  }
}
