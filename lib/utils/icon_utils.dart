import 'package:flutter/material.dart';

/// Utility functions for icon handling across the app
class IconUtils {
  /// Convert icon name string to IconData
  static IconData getIconData(String iconName) {
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
      case 'timer':
        return Icons.timer;
      case 'phone':
        return Icons.phone;
      case 'home':
        return Icons.home;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      default:
        return Icons.check_circle;
    }
  }
}

/// Extension to get icon from habit icon name
extension HabitIconExtension on String {
  IconData get toIconData => IconUtils.getIconData(this);
}
