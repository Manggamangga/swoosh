import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double pageHorizontal = 20;
  static const double cardPadding = 20;
  static const double listItemVertical = 10;
  static const double sectionGap = 20;
  static const double iconGap = 14;
  static const double iconSize = 44;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

abstract final class AppTextStyles {
  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      );

  static TextStyle captionMuted(BuildContext context) => TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
      );

  static TextStyle label(BuildContext context) => TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      );

  static TextStyle sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
          );

  static TextStyle headlineBalance(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge!.copyWith(
            fontWeight: FontWeight.w800,
          );

  static TextStyle amount(BuildContext context, {Color? color}) => TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle tileTitle(BuildContext context) => const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: AppColors.textPrimary,
      );

  static TextStyle tileSubtitle(BuildContext context) => const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      );

  static TextStyle bodyMuted(BuildContext context) => TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      );
}
