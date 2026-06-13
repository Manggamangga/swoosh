import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';

enum SwooshCardVariant { surface, elevated }

class SwooshCard extends StatelessWidget {
  const SwooshCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.margin,
    this.variant = SwooshCardVariant.surface,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final SwooshCardVariant variant;

  Color get _backgroundColor =>
      variant == SwooshCardVariant.elevated
          ? AppColors.surfaceElevated
          : AppColors.surface;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: card,
      ),
    );
  }
}
