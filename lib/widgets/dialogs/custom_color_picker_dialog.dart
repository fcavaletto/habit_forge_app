import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../utils/color_extensions.dart';

class CustomColorPickerDialog extends StatefulWidget {
  final Function(Color lightColor, Color darkColor) onColorSelected;
  
  const CustomColorPickerDialog({
    super.key,
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
    _lightVariant = _generateThemeVariant(_selectedColor, Brightness.light);
    _darkVariant = _generateThemeVariant(_selectedColor, Brightness.dark);
  }
  
  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
      _updateVariants();
    });
  }
  
  void _confirmSelection() {
    widget.onColorSelected(_lightVariant!, _darkVariant!);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  /// Generate theme variant of a color using HSL adjustment
  Color _generateThemeVariant(Color color, Brightness targetBrightness) {
    final hsl = HSLColor.fromColor(color);
    if (targetBrightness == Brightness.dark) {
      // For dark theme: make colors LIGHTER for better visibility
      return HSLColor.fromColor(color.lighten(0.1))
          .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
          .toColor();
    } else {
      // For light theme: make colors DARKER for better contrast
      return HSLColor.fromColor(color.darken(0.1))
          .withSaturation((hsl.saturation - 0.15).clamp(0.0, 1.0))
          .toColor();
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme Preview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: _lightVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.colorScheme.outline, width: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Light Theme', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: _darkVariant,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.colorScheme.outline, width: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Dark Theme', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _confirmSelection, child: const Text('Confirm')),
      ],
    );
  }
}