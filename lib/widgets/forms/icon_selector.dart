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

  /// Themed groups for faster scanning (6 groups × 8 icons = 48 total)
  static const Map<String, List<String>> availableIconGroups = {
    'Core & Self': [
      'local_fire_department',
      'favorite',
      'self_improvement',
      'lightbulb',
      'palette',
      'music_note',
      'book',
      'bed',
    ],
    'Health & Fitness': [
      'fitness_center',
      'directions_run',
      'hiking',
      'sports_soccer',
      'sports_tennis',
      'monitor_heart',
      'spa',
      'nature',
    ],
    'Mindfulness & Wellness': [
      'psychology',
      'volunteer_activism',
      'pets',
      'eco',
      'recycling',
      'healing',
      'water_drop',
      'timer',
    ],
    'Learning & Productivity': [
      'school',
      'library_books',
      'code',
      'create',
      'science',
      'language',
      'translate',
      'security',
    ],
    'Home & Life Admin': [
      'home',
      'handyman',
      'work',
      'account_balance',
      'savings',
      'camera_alt',
      'directions_car',
      'flight',
    ],
    'Food & Social': [
      'local_drink',
      'local_dining',
      'no_food',
      'restaurant',
      'celebration',
      'theater_comedy',
      'games',
      'movie',
    ],
  };

  /// Flattened list for any callers relying on the full set
  static List<String> get availableIcons => [
    for (final group in availableIconGroups.values) ...group,
  ];

  @override
  Widget build(BuildContext context) {
    final totalIcons = availableIcons.length; // 48 icons
    const rows = 4; // fixed rows
    return Semantics(
      label: 'Icon selection',
      hint: 'Choose an icon for your habit. Swipe horizontally to see more icons.',
      child: _buildIconGrid(context, totalIcons, rows),
    );
  }

  /// Builds the scrollable grid of icons
  Widget _buildIconGrid(BuildContext context, int totalIcons, int rows) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _calculateLayout(constraints.maxWidth);
          return _buildAdaptiveIconGrid(context, totalIcons, rows, layout);
        },
      ),
    );
  }

  /// Calculates optimal layout parameters based on available width
  _IconLayoutParams _calculateLayout(double availableWidth) {
    // Define constants
    const spacing = 12.0;
    const minIconSize = 40.0;
    const totalColumns = 12; // 48 icons / 4 rows = 12 columns
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
      // Landscape: Show more columns but still allow scrolling
      // Show approximately 8-10 columns visible, rest scrollable
      const targetVisibleColumns = 8.5; // 8 full + 0.5 partial

      // Calculate icon size based on visible columns
      iconSize =
          (availableWidth - (spacing * (targetVisibleColumns.floor() + 1))) /
          targetVisibleColumns;

      // Apply minimum size constraint
      iconSize = math.max(iconSize, minIconSize);

      // Calculate how many columns are actually visible
      visibleColumns = (availableWidth - spacing) / (iconSize + spacing);

      // Calculate scrollable width for all columns
      scrollableWidth = (iconSize + spacing) * totalColumns;
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
                padding: EdgeInsets.only(
                  bottom: rowIndex < rows - 1 ? layout.spacing : 0,
                ),
                child: Row(
                  children: List.generate(layout.totalColumns, (colIndex) {
                    // Calculate the actual icon index for this position
                    final iconIndex =
                        (rowIndex * layout.totalColumns) + colIndex;

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

  Widget _buildIconButton(
    BuildContext context,
    String iconName,
    int index,
    double size,
    double rightSpacing,
  ) {
    final isSelected = iconName == selectedIconName;
    final iconLabel = iconName.replaceAll('_', ' ');

    // Wrap each icon button with RepaintBoundary for isolated repaints
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(right: rightSpacing),
        child: Semantics(
          label: '$iconLabel icon${isSelected ? ', selected' : ''}',
          hint: isSelected
              ? 'Currently selected icon'
              : 'Tap to select this icon',
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
                          ),
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
      ),
    );
  }
}
