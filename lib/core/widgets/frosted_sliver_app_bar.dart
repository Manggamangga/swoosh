import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';

class FrostedSliverAppBar extends StatelessWidget {
  const FrostedSliverAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  final Widget title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
      title: title,
      actions: actions,
    );
  }
}
