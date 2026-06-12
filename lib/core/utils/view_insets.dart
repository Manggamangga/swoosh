import 'package:flutter/material.dart';

abstract final class ViewInsets {  static const navigationBarHeight = 72.0;

  static double safeBottom(BuildContext context) {
    final view = View.of(context);
    return view.viewPadding.bottom / view.devicePixelRatio;
  }

  static double bottomClearance(BuildContext context) {
    return navigationBarHeight + safeBottom(context);
  }

  static EdgeInsets listPadding(
    BuildContext context, {
    double horizontal = 20,
    double top = 0,
    bool includeFab = false,
  }) {
    final fabExtra = includeFab ? 72.0 : 0.0;
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      bottomClearance(context) + fabExtra,
    );
  }

  static EdgeInsets snackBarMargin(BuildContext context) {
    return EdgeInsets.fromLTRB(16, 16, 16, 16 + safeBottom(context));
  }
}
