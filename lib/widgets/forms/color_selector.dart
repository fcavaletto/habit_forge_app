import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme.dart';

/// Layout parameters for the adaptive color grid
class _LayoutParams {
  final double colorSize;
  final double visibleColumns;
  final int totalColumns;
  final double scrollableWidth;
  final double spacing;
  final bool isPortrait;

  const _LayoutParams({
    required this.colorSize,
    required this.visibleColumns,
    required this.totalColumns,
    required this.scrollableWidth,
    required this.spacing,
    required this.isPortrait,
  });
}

/// Color selector widget for habit creation/editing
///
/// Displays a responsive grid of predefined colors that users can select from.
/// Shows a checkmark on the selected color and provides visual feedback.
/// Supports both 24-color (default) and 36-color (extended) modes.
/// Features horizontal scrolling with partial visibility of additional colors.
class ColorSelector extends StatelessWidget {
  final int selectedColorIndex;
  final Function(int) onColorSelected;

  const ColorSelector({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isExtendedMode = appState.isExtendedColorPalette;
        final colors = Theme.of(context).colorScheme.habitColors;
        const totalColors = 36; // Always use full palette, limit display based on mode
        final rows = isExtendedMode ? 3 : 2;
        
    return Semantics(
      label: 'Color selection',
          hint: 'Choose a color for your habit. Swipe horizontally to see more colors.',
          child: _buildColorGrid(context, colors, totalColors, rows),
        );
      },
    );
  }

  Widget _buildColorGrid(BuildContext context, List<Color> colors, int totalColors, int rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate layout parameters based on available width
        final layout = _calculateLayout(constraints.maxWidth);
        
        // Debug information
        debugPrint('🎨 LayoutBuilder Color Grid Debug:');
        debugPrint('   - Available width: ${constraints.maxWidth}');
        debugPrint('   - Calculated color size: ${layout.colorSize}');
        debugPrint('   - Visible columns: ${layout.visibleColumns}');
        debugPrint('   - Total columns: ${layout.totalColumns}');
        debugPrint('   - Scrollable width: ${layout.scrollableWidth}');
        debugPrint('   - Is portrait: ${layout.isPortrait}');
        
        return _buildAdaptiveColorGrid(context, colors, totalColors, rows, layout);
      },
    );
  }

  /// Calculates optimal layout parameters based on available width
  _LayoutParams _calculateLayout(double availableWidth) {
    // Define constants
    const spacing = 12.0;
    const minColorSize = 40.0;
    const totalColumns = 12;
    const targetVisibleColumns = 6.35; // 6 full + 0.35 partial
    
    // Determine if we're in portrait mode (heuristic: width < 600)
    final isPortrait = availableWidth < 600;
    
    double colorSize;
    double visibleColumns;
    double scrollableWidth;
    
    if (isPortrait) {
      // Portrait: Show exactly 6.35 columns (6 full + 0.35 partial)
      // Formula: availableWidth = (6 * (colorSize + spacing)) + (0.35 * colorSize) + spacing
      // Solving for colorSize: colorSize = (availableWidth - spacing * 7) / 6.35
      colorSize = (availableWidth - (spacing * 7)) / targetVisibleColumns;
      
      // Apply minimum size constraint
      colorSize = math.max(colorSize, minColorSize);
      
      // Calculate how many columns are actually visible
      visibleColumns = (availableWidth - spacing) / (colorSize + spacing);
      
      // Calculate scrollable width for all columns
      scrollableWidth = (colorSize + spacing) * totalColumns;
    } else {
      // Landscape: Show all 12 columns with appropriate sizing
      colorSize = (availableWidth - (spacing * (totalColumns + 1))) / totalColumns;
      
      // Apply minimum size constraint
      colorSize = math.max(colorSize, minColorSize);
      
      // In landscape, show all columns
      visibleColumns = totalColumns.toDouble();
      scrollableWidth = availableWidth;
    }
    
    return _LayoutParams(
      colorSize: colorSize,
      visibleColumns: visibleColumns,
      totalColumns: totalColumns,
      scrollableWidth: scrollableWidth,
      spacing: spacing,
      isPortrait: isPortrait,
    );
  }

  /// Builds the adaptive color grid with proper scrolling and partial visibility
  Widget _buildAdaptiveColorGrid(
    BuildContext context,
    List<Color> colors,
    int totalColors,
    int rows,
    _LayoutParams layout,
  ) {
    return SizedBox(
      height: (layout.colorSize * rows) + (layout.spacing * (rows - 1)),
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
                    // Calculate the actual color index for this position
                    final colorIndex = (rowIndex * layout.totalColumns) + colIndex;
                    
                    // Check if this color index is within our total colors
                    if (colorIndex >= totalColors) {
                      return const SizedBox.shrink();
                    }
                    
                    return _buildColorButton(
                      context,
                      colors[colorIndex],
                      colorIndex,
                      layout.colorSize,
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


  Widget _buildColorButton(BuildContext context, Color color, int index, double size, double rightSpacing) {
          final isSelected = index == selectedColorIndex;
          final colorName = _getColorName(index);

    return Padding(
      padding: EdgeInsets.only(right: rightSpacing),
      child: Semantics(
            label: '$colorName color${isSelected ? ', selected' : ''}',
            hint: isSelected ? 'Currently selected color' : 'Tap to select this color',
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => onColorSelected(index),
              child: Focus(
                autofocus: isSelected,
                child: Container(
              width: size,
              height: size,
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
      ),
    );
  }

  String _getColorName(int index) {
    const colorNames = [
      // Warm Tones (9 colors)
      'Soft Pink', 'Coral', 'Peach', 'Warm Beige', 'Rose', 'Light Coral', 'Apricot', 'Dusty Rose', 'Cream',
      // Cool Tones (9 colors)
      'Soft Cyan', 'Sky Blue', 'Mint Green', 'Lavender', 'Seafoam', 'Powder Blue', 'Sage Green', 'Soft Purple', 'Aqua',
      // Neutral Tones (9 colors)
      'Soft Gray', 'Warm Gray', 'Light Taupe', 'Silver', 'Muted Mauve', 'Off White', 'Soft Brown', 'Light Silver', 'Dusty Mauve',
      // Accent Colors (9 colors)
      'Soft Yellow', 'Light Green', 'Cream Yellow', 'Light Lime', 'Lemon Chiffon', 'Light Blue', 'Moccasin', 'Pale Turquoise', 'Peach Puff',
    ];
    return colorNames[index % colorNames.length];
  }
}
