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
    Color(0xFFE6194B), // Red - Urgency, important habits, health
    Color(0xFF3CB44B), // Green - Success, growth, nature
    Color(0xFFFFE119), // Yellow - Happiness, optimism, social
    Color(0xFF4363D8), // Blue - Trust, calm, productivity
    Color(0xFFF58231), // Orange - Energy, enthusiasm, creativity
    Color(0xFF911EB4), // Purple - Luxury, mindfulness, spirituality
    Color(0xFF46F0F0), // Cyan - Freshness, clarity, learning
    Color(0xFFF032E6), // Magenta - Bold, creative, artistic
    Color(0xFFBCF60C), // Lime - Fresh, energetic, environmental
    Color(0xFFFABEBE), // Pink - Love, relationships, self-care
    Color(0xFF008080), // Teal - Balance, professionalism, work
    Color(0xFFE6BEFF), // Lavender - Calm, meditation, wellness
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
      'Red', 'Green', 'Yellow', 'Blue', 'Orange', 'Purple',
      'Cyan', 'Magenta', 'Lime', 'Pink', 'Teal', 'Lavender'
    ];
    return colorNames[index % colorNames.length];
  }
}
