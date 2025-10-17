import 'package:flutter/services.dart';

class HapticFeedbackService {
  static void light() {
    HapticFeedback.lightImpact();
  }

  static void medium() {
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  static void error() {
    // Triple tap pattern
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.lightImpact();
      });
    });
  }

  static void selection() {
    HapticFeedback.selectionClick();
  }
}