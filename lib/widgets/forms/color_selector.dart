import 'package:flutter/material.dart';

/// Color selector widget for habit creation/editing
///
/// Displays a grid of predefined colors that users can select from.
/// Shows a checkmark on the selected color and provides visual feedback.
class ColorSelector extends StatelessWidget {
  final int selectedColorIndex;
  final Function(int) onColorSelected;

  const ColorSelector({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
  });

  static const List<Color> habitColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFC107), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFFE91E63), // Pink
    Color(0xFF607D8B), // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Color selection',
      hint: 'Choose a color for your habit',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(habitColors.length, (index) {
          final color = habitColors[index];
          final isSelected = index == selectedColorIndex;
          final colorName = _getColorName(index);

          return Semantics(
            label: '$colorName color${isSelected ? ', selected' : ''}',
            hint: isSelected ? 'Currently selected color' : 'Tap to select this color',
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => onColorSelected(index),
              child: Focus(
                autofocus: isSelected,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              spreadRadius: 2,
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getColorName(int index) {
    const colorNames = [
      'Green', 'Blue', 'Orange', 'Red', 'Purple',
      'Cyan', 'Yellow', 'Brown', 'Pink', 'Blue Grey'
    ];
    return colorNames[index % colorNames.length];
  }
}
