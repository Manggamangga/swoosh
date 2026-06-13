import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static void selection() => HapticFeedback.selectionClick();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  static void success() => HapticFeedback.mediumImpact();
}
