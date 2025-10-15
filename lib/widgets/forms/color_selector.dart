import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme.dart';
import '../../services/custom_color_service.dart';
import '../dialogs/custom_color_picker_dialog.dart';

/// Color selector widget for habit creation/editing
///
/// Displays a static grid of predefined colors that users can select from.
/// Shows a checkmark on the selected color and provides visual feedback.
/// Supports both 7-color (default) and 21-color (extended) modes.
/// Features a custom color picker as the 21st color option.
class ColorSelector extends StatelessWidget {
  final int selectedColorIndex;
  final Function(int) onColorSelected;
  final CustomColorService? customColorService;

  const ColorSelector({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
    this.customColorService,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, bool>(
      selector: (context, appState) => appState.isExtendedColorPalette,
      builder: (context, isExtendedMode, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final brightness = Theme.of(context).brightness;
        
        // Determine number of rows and colors to show
        const colorsPerRow = 7;
        final actualRows = isExtendedMode ? 3 : 1;
        final totalColors = actualRows * colorsPerRow;
        
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
      },
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
        
        // Calculate color size to fit available width
        final availableWidth = constraints.maxWidth;
        final colorSize = ((availableWidth - (colorsPerRow - 1) * spacing) / colorsPerRow)
            .clamp(minColorSize, 60.0);
        
        return SizedBox(
          height: (colorSize * rows) + (spacing * (rows - 1)),
          child: Column(
            children: List.generate(rows, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex < rows - 1 ? spacing : 0),
                child: Row(
                  children: List.generate(colorsPerRow, (colIndex) {
                    final colorIndex = (rowIndex * colorsPerRow) + colIndex;
                    
                    // Check if this color index is within our total colors
                    if (colorIndex >= totalColors) {
                      return const SizedBox.shrink();
                    }
                    
                    return _buildColorButton(
                      context,
                      colorScheme,
                      brightness,
                      colorIndex,
                      colorSize,
                      colIndex < colorsPerRow - 1 ? spacing : 0,
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
    final isSelected = colorIndex == selectedColorIndex;
    final isCustomColor = colorIndex == 20;
    
    return Padding(
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
    // Get custom color if available
    final customColor = customColorService?.getCustomColor(brightness);
    
    if (customColor != null) {
      // Show custom color with palette icon
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: customColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: customColor.withValues(alpha: 0.3),
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
            : const Icon(
                Icons.palette,
                color: Colors.white,
                size: 20,
              ),
      );
    } else {
      // Show multicolor gradient when no custom color is set
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
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
            : const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
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
    final color = colorScheme.getHabitColor(colorIndex, brightness);
    
    return Container(
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
    );
  }
  
  void _handleColorTap(BuildContext context, int colorIndex) {
    if (colorIndex == 20) {
      // Show custom color picker dialog
      if (customColorService != null) {
        showDialog(
          context: context,
          builder: (context) => CustomColorPickerDialog(
            customColorService: customColorService!,
            onColorSelected: onColorSelected,
          ),
        );
      }
    } else {
      // Select predefined color
      onColorSelected(colorIndex);
    }
  }

  String _getColorName(int index) {
    const colorNames = [
      // Row 1: Essential Colors (0-6)
      'Blue', 'Green', 'Red', 'Purple', 'Orange', 'Cyan', 'Pink',
      // Row 2: Secondary Colors (7-13)
      'Indigo', 'Teal', 'Light Green', 'Amber', 'Brown', 'Blue Grey', 'Deep Purple',
      // Row 3: Tertiary Colors (14-19)
      'Dark Green', 'Dark Red', 'Dark Blue', 'Dark Purple', 'Deep Orange', 'Dark Teal',
      // Custom Color (20)
      'Custom Color',
    ];
    return colorNames[index % colorNames.length];
  }
}