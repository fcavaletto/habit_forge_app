import 'package:flutter/material.dart';

/// Utility functions for icon handling across the app
/// This is the SINGLE SOURCE OF TRUTH for all icon mappings
class IconUtils {
  /// Convert icon name string to IconData
  /// This method handles all registered icon names used in the app
  static IconData getIconData(String iconName) {
    switch (iconName) {
      // Row 1: Essential & Core Habits
      case 'local_fire_department':
        return Icons.local_fire_department;
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

      // Row 2: Health & Wellness
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
      case 'local_hospital':
        return Icons.local_hospital;
      case 'medication':
        return Icons.medication;
      case 'monitor_heart':
        return Icons.monitor_heart;
      case 'psychology':
        return Icons.psychology;
      case 'healing':
        return Icons.healing;
      case 'masks':
        return Icons.masks;
      case 'sanitizer':
        return Icons.sanitizer;
      case 'vaccines':
        return Icons.vaccines;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'cake':
        return Icons.cake;
      case 'local_pizza':
        return Icons.local_pizza;
      case 'no_food':
        return Icons.no_food;

      // Row 3: Learning & Productivity
      case 'water_drop':
        return Icons.water_drop;
      case 'air':
        return Icons.air;
      case 'thermostat':
        return Icons.thermostat;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'library_books':
        return Icons.library_books;
      case 'handyman':
        return Icons.handyman;
      case 'account_balance':
        return Icons.account_balance;
      case 'language':
        return Icons.language;
      case 'translate':
        return Icons.translate;
      case 'savings':
        return Icons.savings;
      case 'science':
        return Icons.science;
      case 'biotech':
        return Icons.biotech;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'security':
        return Icons.security;
      case 'headphones':
        return Icons.headphones;
      case 'smartphone':
        return Icons.smartphone;
      case 'email':
        return Icons.email;
      case 'chat':
        return Icons.chat;

      // Row 4: Lifestyle & Activities
      case 'video_call':
        return Icons.video_call;
      case 'wifi':
        return Icons.wifi;
      case 'directions_car':
        return Icons.directions_car;
      case 'directions_bike':
        return Icons.directions_bike;
      case 'hiking':
        return Icons.hiking;
      case 'flight':
        return Icons.flight;
      case 'eco':
        return Icons.eco;
      case 'recycling':
        return Icons.recycling;
      case 'solar_power':
        return Icons.solar_power;
      case 'wind_power':
        return Icons.wind_power;
      case 'movie':
        return Icons.movie;
      case 'theater_comedy':
        return Icons.theater_comedy;
      case 'games':
        return Icons.games;
      case 'sports_tennis':
        return Icons.sports_tennis;
      case 'casino':
        return Icons.casino;
      case 'celebration':
        return Icons.celebration;
      case 'cookie':
        return Icons.cookie;
      case 'local_dining':
        return Icons.local_dining;

      // Backward compatibility for default icon name
      case 'check_circle':
        return Icons.local_fire_department; // Map old default to fire icon

      default:
        return Icons
            .local_fire_department; // Default to fire icon for HabitForge theme
    }
  }
}

/// Extension to get icon from habit icon name
extension HabitIconExtension on String {
  IconData get toIconData => IconUtils.getIconData(this);
}
