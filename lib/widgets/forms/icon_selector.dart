import 'package:flutter/material.dart';

/// Icon selector widget for habit creation/editing
///
/// Displays a grid of available icons that users can select from.
/// Highlights the currently selected icon and provides visual feedback.
class IconSelector extends StatelessWidget {
  final String selectedIconName;
  final Function(String) onIconSelected;

  const IconSelector({
    super.key,
    required this.selectedIconName,
    required this.onIconSelected,
  });

  static const List<String> availableIcons = [
    'check_circle',
    'fitness_center',
    'local_drink',
    'book',
    'bed',
    'restaurant',
    'directions_run',
    'school',
    'work',
    'favorite',
    'music_note',
    'self_improvement',
    'spa',
    'sports_soccer',
    'palette',
    'code',
    'create',
    'lightbulb',
    'nature',
    'pets',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: availableIcons.map((iconName) {
        final isSelected = iconName == selectedIconName;
        return GestureDetector(
          onTap: () => onIconSelected(iconName),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              _getIconData(iconName),
              color: isSelected ? Colors.blue : Colors.black,
              size: 24,
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'local_drink':
        return Icons.local_drink;
      case 'book':
        return Icons.book;
      case 'bed':
        return Icons.bed;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_run':
        return Icons.directions_run;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'favorite':
        return Icons.favorite;
      case 'music_note':
        return Icons.music_note;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'spa':
        return Icons.spa;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'create':
        return Icons.create;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'nature':
        return Icons.nature;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.check_circle;
    }
  }
}
