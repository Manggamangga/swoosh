import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 56 : 72;
    final iconGlyphSize = compact ? 28 : 36;
    final padding = compact ? AppSpacing.xxl : AppSpacing.xxxl;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconSize.toDouble(),
              height: iconSize.toDouble(),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                icon,
                size: iconGlyphSize.toDouble(),
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTextStyles.bodyMuted(context),
              textAlign: TextAlign.center,
            ),
            if (_hasActions) ...[
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasActions =>
      action != null ||
      (actionLabel != null && onAction != null) ||
      (secondaryActionLabel != null && onSecondaryAction != null);

  Widget _buildActions(BuildContext context) {
    if (action != null) return action!;

    final children = <Widget>[];

    if (actionLabel != null && onAction != null) {
      children.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ),
      );
    }

    if (secondaryActionLabel != null && onSecondaryAction != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
      children.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onSecondaryAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
            ),
            child: Text(secondaryActionLabel!),
          ),
        ),
      );
    }

    return Column(children: children);
  }
}
