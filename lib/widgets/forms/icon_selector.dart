import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/icon_utils.dart';

/// Layout parameters for the adaptive icon grid
class _IconLayoutParams {
  final double iconSize;
  final double visibleColumns;
  final int totalColumns;
  final double scrollableWidth;
  final double spacing;
  final bool isPortrait;

  const _IconLayoutParams({
    required this.iconSize,
    required this.visibleColumns,
    required this.totalColumns,
    required this.scrollableWidth,
    required this.spacing,
    required this.isPortrait,
  });
}

/// Icon selector widget for habit creation/editing
///
/// Displays a responsive grid of available icons that users can select from.
/// Highlights the currently selected icon and provides visual feedback.
/// Features horizontal scrolling with partial visibility of additional icons.
class IconSelector extends StatelessWidget {
  final String selectedIconName;
  final Function(String) onIconSelected;

  const IconSelector({
    super.key,
    required this.selectedIconName,
    required this.onIconSelected,
  });

  static const List<String> availableIcons = [
    // Row 1: Essential & Core Habits (18 icons)
    'local_fire_department',
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
    
    // Row 2: Health & Wellness (18 icons)
    'nature',
    'pets',
    'timer',
    'phone',
    'home',
    'volunteer_activism',
    'local_hospital',
    'medication',
    'monitor_heart',
    'psychology',
    'healing',
    'masks',
    'sanitizer',
    'vaccines',
    'restaurant_menu',
    'cake',
    'local_pizza',
    'no_food',
    
    // Row 3: Learning & Productivity (18 icons)
    'water_drop',
    'air',
    'thermostat',
    'ac_unit',
    'library_books',
    'handyman',
    'account_balance',
    'language',
    'translate',
    'savings',
    'science',
    'biotech',
    'camera_alt',
    'security',
    'headphones',
    'smartphone',
    'email',
    'chat',
    
    // Row 4: Lifestyle & Activities (18 icons)
    'video_call',
    'wifi',
    'directions_car',
    'directions_bike',
    'hiking',
    'flight',
    'eco',
    'recycling',
    'solar_power',
    'wind_power',
    'movie',
    'theater_comedy',
    'games',
    'sports_tennis',
    'casino',
    'celebration',
    'cookie',
    'local_dining',
  ];

  @override
  Widget build(BuildContext context) {
    const totalIcons = 72; // Total number of icons
    const rows = 4; // Always 4 rows
    
    return Semantics(
      label: 'Icon selection',
      hint: 'Choose an icon for your habit. Swipe horizontally to see more icons.',
      child: _buildIconGrid(context, totalIcons, rows),
    );
  }

  Widget _buildIconGrid(BuildContext context, int totalIcons, int rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate layout parameters based on available width
        final layout = _calculateLayout(constraints.maxWidth);
        
        // Debug information
        debugPrint('🎯 LayoutBuilder Icon Grid Debug:');
        debugPrint('   - Available width: ${constraints.maxWidth}');
        debugPrint('   - Calculated icon size: ${layout.iconSize}');
        debugPrint('   - Visible columns: ${layout.visibleColumns}');
        debugPrint('   - Total columns: ${layout.totalColumns}');
        debugPrint('   - Scrollable width: ${layout.scrollableWidth}');
        debugPrint('   - Is portrait: ${layout.isPortrait}');
        
        return _buildAdaptiveIconGrid(context, totalIcons, rows, layout);
      },
    );
  }

  /// Calculates optimal layout parameters based on available width
  _IconLayoutParams _calculateLayout(double availableWidth) {
    // Define constants
    const spacing = 12.0;
    const minIconSize = 40.0;
    const totalColumns = 18; // 72 icons / 4 rows = 18 columns
    const targetVisibleColumns = 6.35; // 6 full + 0.35 partial
    
    // Determine if we're in portrait mode (heuristic: width < 600)
    final isPortrait = availableWidth < 600;
    
    double iconSize;
    double visibleColumns;
    double scrollableWidth;
    
    if (isPortrait) {
      // Portrait: Show exactly 6.35 columns (6 full + 0.35 partial)
      // Formula: availableWidth = (6 * (iconSize + spacing)) + (0.35 * iconSize) + spacing
      // Solving for iconSize: iconSize = (availableWidth - spacing * 7) / 6.35
      iconSize = (availableWidth - (spacing * 7)) / targetVisibleColumns;
      
      // Apply minimum size constraint
      iconSize = math.max(iconSize, minIconSize);
      
      // Calculate how many columns are actually visible
      visibleColumns = (availableWidth - spacing) / (iconSize + spacing);
      
      // Calculate scrollable width for all columns
      scrollableWidth = (iconSize + spacing) * totalColumns;
    } else {
      // Landscape: Show all 18 columns with appropriate sizing
      iconSize = (availableWidth - (spacing * (totalColumns + 1))) / totalColumns;
      
      // Apply minimum size constraint
      iconSize = math.max(iconSize, minIconSize);
      
      // In landscape, show all columns
      visibleColumns = totalColumns.toDouble();
      scrollableWidth = availableWidth;
    }
    
    return _IconLayoutParams(
      iconSize: iconSize,
      visibleColumns: visibleColumns,
      totalColumns: totalColumns,
      scrollableWidth: scrollableWidth,
      spacing: spacing,
      isPortrait: isPortrait,
    );
  }

  /// Builds the adaptive icon grid with proper scrolling and partial visibility
  Widget _buildAdaptiveIconGrid(
    BuildContext context,
    int totalIcons,
    int rows,
    _IconLayoutParams layout,
  ) {
    return SizedBox(
      height: (layout.iconSize * rows) + (layout.spacing * (rows - 1)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: layout.scrollableWidth,
          child: Column(
            children: List.generate(rows, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex < rows - 1 ? layout.spacing : 0),
                child: Row(
                  children: List.generate(layout.totalColumns, (colIndex) {
                    // Calculate the actual icon index for this position
                    final iconIndex = (rowIndex * layout.totalColumns) + colIndex;
                    
                    // Check if this icon index is within our total icons
                    if (iconIndex >= totalIcons) {
                      return const SizedBox.shrink();
                    }
                    
                    return _buildIconButton(
                      context,
                      availableIcons[iconIndex],
                      iconIndex,
                      layout.iconSize,
                      layout.spacing,
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, String iconName, int index, double size, double rightSpacing) {
    final isSelected = iconName == selectedIconName;
    final iconLabel = iconName.replaceAll('_', ' ');

    return Padding(
      padding: EdgeInsets.only(right: rightSpacing),
      child: Semantics(
        label: '$iconLabel icon${isSelected ? ', selected' : ''}',
        hint: isSelected ? 'Currently selected icon' : 'Tap to select this icon',
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: () => onIconSelected(iconName),
          child: Focus(
            autofocus: isSelected,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          spreadRadius: 2,
                          blurRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                iconName.toIconData,
                color: isSelected ? Colors.blue : Colors.black,
                size: size * 0.5, // Icon size is half of container size
              ),
            ),
          ),
        ),
      ),
    );
  }

}
