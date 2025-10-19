import 'package:flutter/material.dart';

extension ColorAdjustments on Color {
  /// Lightens this color by the given [percentage].
  /// 
  /// [percentage] should be between 0.0 and 1.0 (e.g., 0.4 for 40% lighter).
  /// The result is automatically clamped to valid color ranges.
  Color lighten(double percentage) {
    assert(percentage >= 0.0 && percentage <= 1.0);
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness + percentage).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  /// Darkens this color by the given [percentage].
  /// 
  /// [percentage] should be between 0.0 and 1.0 (e.g., 0.2 for 20% darker).
  /// The result is automatically clamped to valid color ranges.
  Color darken(double percentage) {
    assert(percentage >= 0.0 && percentage <= 1.0);
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness - percentage).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }
}
