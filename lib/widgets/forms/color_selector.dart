import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/app_state_provider.dart';
import '../dialogs/custom_color_picker_dialog.dart';
import '../dialogs/pro_upgrade_dialog.dart';

/// Color selector widget for habit creation/editing
///
/// Displays a static grid of 20 predefined colors plus 1 custom color option.
/// Shows a checkmark on the selected color and provides visual feedback.
/// The custom color picker (21st option) requires an active PRO subscription.
class ColorSelector extends StatelessWidget {
  final Color selectedLightColor;
  final Color selectedDarkColor;
  final Function(Color lightColor, Color darkColor) onColorSelected;

  const ColorSelector({
    super.key,
    required this.selectedLightColor,
    required this.selectedDarkColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    
    const colorsPerRow = 7;
    const actualRows = 3; // Always show all 3 rows
    const totalColors = 21; // 20 colors + 1 custom
    
    return Semantics(
      label: 'Color selection',
      hint: 'Choose a color for your habit.',
      child: _buildColorGrid(
        context,
        colorScheme,
        brightness,
        actualRows,
        colorsPerRow,
        totalColors
      ),
    );
  }

  Widget _buildColorGrid(
    BuildContext context,
    ColorScheme colorScheme,
    Brightness brightness,
    int rows,
    int colorsPerRow,
    int totalColors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const minColorSize = 40.0;
        const maxColorSize = 60.0;
        
        final availableWidth = constraints.maxWidth;
        final isLandscape = availableWidth > 600;
        
        // In landscape, show more colors per row
        final actualColorsPerRow = isLandscape ? (colorsPerRow * 1.5).round() : colorsPerRow;
        final actualRows = isLandscape ? (totalColors / actualColorsPerRow).ceil() : rows;
        
        final colorSize = ((availableWidth - (actualColorsPerRow - 1) * spacing) / actualColorsPerRow)
            .clamp(minColorSize, maxColorSize);
        
    return SizedBox(
          height: (colorSize * actualRows) + (spacing * (actualRows - 1)),
          child: Column(
            children: List.generate(actualRows, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex < actualRows - 1 ? spacing : 0),
                child: Row(
                  children: List.generate(actualColorsPerRow, (colIndex) {
                    final colorIndex = (rowIndex * actualColorsPerRow) + colIndex;
                    
                    if (colorIndex >= totalColors) {
                      return const SizedBox.shrink();
                    }
                    
                    return _buildColorButton(
                      context,
                      colorScheme,
                      brightness,
                      colorIndex,
                      colorSize,
                      colIndex < actualColorsPerRow - 1 ? spacing : 0,
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildColorButton(
    BuildContext context,
    ColorScheme colorScheme,
    Brightness brightness,
    int colorIndex,
    double size,
    double rightSpacing,
  ) {
    final isCustomColor = colorIndex == 20;
    final isSelected = _isColorSelected(context, colorIndex, brightness);
    
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(right: rightSpacing),
        child: Semantics(
          label: '${_getColorName(colorIndex)} color${isSelected ? ', selected' : ''}',
          hint: isSelected ? 'Currently selected color' : 'Tap to select this color',
          button: true,
          selected: isSelected,
          child: GestureDetector(
            onTap: () => _handleColorTap(context, colorIndex),
            child: Focus(
              autofocus: isSelected,
              child: _buildColorContainer(
                context,
                colorScheme,
                brightness,
                colorIndex,
                size,
                isSelected,
                isCustomColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorContainer(
    BuildContext context,
    ColorScheme colorScheme,
    Brightness brightness,
    int colorIndex,
    double size,
    bool isSelected,
    bool isCustomColor,
  ) {
    if (isCustomColor) {
      return _buildCustomColorContainer(
        context,
        brightness,
        size,
        isSelected,
      );
    } else {
      return _buildPredefinedColorContainer(
        context,
        colorScheme,
        brightness,
        colorIndex,
        size,
        isSelected,
      );
    }
  }

  Widget _buildCustomColorContainer(
    BuildContext context,
    Brightness brightness,
    double size,
    bool isSelected,
  ) {
    // Check if we have a custom color selected
    final hasCustomColor = _hasCustomColorSelected(context);
    
    if (hasCustomColor) {
      final customColor = brightness == Brightness.light ? selectedLightColor : selectedDarkColor;
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: customColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? _getThemeBorderColor(brightness)
                : Colors.transparent, 
            width: 2
          ),
        ),
        child: isSelected 
            ? _buildSelectionIndicator(brightness)
            : const Icon(Icons.palette, color: Colors.white, size: 20),
      );
    } else {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.indigo, Colors.purple],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? _getThemeBorderColor(brightness)
                : Colors.transparent, 
            width: 1
          ),
        ),
        child: isSelected 
            ? _buildSelectionIndicator(brightness)
            : const Icon(Icons.add, color: Colors.white, size: 20),
      );
    }
  }

  Widget _buildPredefinedColorContainer(
    BuildContext context,
    ColorScheme colorScheme,
    Brightness brightness,
    int colorIndex,
    double size,
    bool isSelected,
  ) {
    final colorPair = colorScheme.habitColorPairs[colorIndex];
    final color = colorPair.getColor(brightness);
    
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? _getThemeBorderColor(brightness)
              : Colors.transparent, 
          width: 2
        ),
      ),
      child: isSelected ? _buildSelectionIndicator(brightness) : null,
    );
  }

  void _handleColorTap(BuildContext context, int colorIndex) {
    if (colorIndex == 20) {
      // Check PRO subscription status
      final appState = Provider.of<AppState>(context, listen: false);
      
      if (!appState.isProSubscriptionActive) {
        // Show PRO upgrade dialog
        showDialog(
          context: context,
          builder: (context) => ProUpgradeDialog(
            title: 'Custom Colors',
            message: 'Unlock custom colors with PRO! Upgrade to access unlimited color customization for your habits.',
            onUpgrade: () {
              // For now, do nothing when "Upgrade to Pro" is tapped
              // TODO: Implement actual upgrade flow
            },
          ),
        );
        return;
      }
      
      // PRO is active - show color picker
      showDialog(
        context: context,
        builder: (context) => CustomColorPickerDialog(
          onColorSelected: (lightColor, darkColor) {
            onColorSelected(lightColor, darkColor);
          },
        ),
      );
    } else {
      final colorPair = Theme.of(context).colorScheme.habitColorPairs[colorIndex];
      onColorSelected(colorPair.light, colorPair.dark);
    }
  }

  bool _isColorSelected(BuildContext context, int colorIndex, Brightness brightness) {
    if (colorIndex == 20) {
      return _hasCustomColorSelected(context);
    } else {
      final colorPair = Theme.of(context).colorScheme.habitColorPairs[colorIndex];
      final expectedColor = colorPair.getColor(brightness);
      final selectedColor = brightness == Brightness.light ? selectedLightColor : selectedDarkColor;
      return expectedColor.toARGB32() == selectedColor.toARGB32();
    }
  }

  bool _hasCustomColorSelected(BuildContext context) {
    // Check if the selected colors are not in the predefined palette
    final colorScheme = Theme.of(context).colorScheme;
    for (final colorPair in colorScheme.habitColorPairs) {
      if (colorPair.light.toARGB32() == selectedLightColor.toARGB32() && 
          colorPair.dark.toARGB32() == selectedDarkColor.toARGB32()) {
        return false;
      }
    }
    return true;
  }

  String _getColorName(int index) {
    const colorNames = [
      'Slate', 'Gray', 'Neutral', 'Red', 'Orange', 'Amber', 'Yellow',
      'Lime', 'Green', 'Emerald', 'Teal', 'Cyan', 'Sky', 'Blue',
      'Indigo', 'Violet', 'Purple', 'Fuchsia', 'Pink', 'Rose',
      'Custom Color',
    ];
    return colorNames[index % colorNames.length];
  }

  /// Get theme-consistent border color
  Color _getThemeBorderColor(Brightness brightness) {
    return brightness == Brightness.light ? Colors.black : Colors.white;
  }

  /// Build the selection indicator (circle with contrast border)
  Widget _buildSelectionIndicator(Brightness brightness) {
    final circleColor = _getThemeBorderColor(brightness);
    final borderColor = brightness == Brightness.light ? Colors.white : Colors.black;

    
    return Center(
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: circleColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
    );
  }
}