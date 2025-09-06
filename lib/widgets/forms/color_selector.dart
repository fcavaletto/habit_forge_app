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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(habitColors.length, (index) {
        final color = habitColors[index];
        final isSelected = index == selectedColorIndex;

        return GestureDetector(
          onTap: () => onColorSelected(index),
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
        );
      }),
    );
  }
}
