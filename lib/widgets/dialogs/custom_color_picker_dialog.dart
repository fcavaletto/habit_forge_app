import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../services/custom_color_service.dart';

/// Dialog for selecting custom habit colors with theme variant preview
///
/// Shows a color wheel picker and previews how the color will look
/// in both light and dark themes. Automatically generates theme variants
/// using HSL color space adjustments.
class CustomColorPickerDialog extends StatefulWidget {
  final CustomColorService customColorService;
  final Function(int) onColorSelected;
  
  const CustomColorPickerDialog({
    super.key,
    required this.customColorService,
    required this.onColorSelected,
  });
  
  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  Color _selectedColor = Colors.blue;
  Color? _lightVariant;
  Color? _darkVariant;
  
  @override
  void initState() {
    super.initState();
    _updateVariants();
  }
  
  void _updateVariants() {
    _lightVariant = widget.customColorService.generateThemeVariant(
      _selectedColor, 
      Brightness.light
    );
    _darkVariant = widget.customColorService.generateThemeVariant(
      _selectedColor, 
      Brightness.dark
    );
  }
  
  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
      _updateVariants();
    });
  }
  
  Future<void> _confirmSelection() async {
    final currentBrightness = Theme.of(context).brightness;
    
    // Save the custom color with auto-generated variant
    await widget.customColorService.saveCustomColorWithVariant(
      _selectedColor, 
      currentBrightness
    );
    
    // Return color index 20 (custom color index)
    widget.onColorSelected(20);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Choose Custom Color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color picker
            ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: _onColorChanged,
              paletteType: PaletteType.hueWheel,
              enableAlpha: false,
              displayThumbColor: true,
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.8,
            ),
            
            const SizedBox(height: 24),
            
            // Theme variant preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Preview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Light theme preview
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _lightVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Light Theme',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Dark theme preview
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _darkVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Dark Theme',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirmSelection,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
