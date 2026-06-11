import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pageHorizontal = 20;
}

abstract final class AppTextStyles {
  static TextStyle caption(BuildContext context) => const TextStyle(
        fontSize: 13,
      );

  static TextStyle captionMuted(BuildContext context) => const TextStyle(
        fontSize: 13,
      );

  static TextStyle sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
          );

  static TextStyle amount(BuildContext context, {Color? color}) => TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: color,
      );
}
