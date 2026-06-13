import 'package:flutter/material.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = AppRadius.sm,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: const [
                AppColors.skeletonBase,
                AppColors.skeletonHighlight,
                AppColors.skeletonBase,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _SkeletonCardContent(maxHeight: constraints.maxHeight);
        },
      ),
    );
  }
}

class _SkeletonCardContent extends StatelessWidget {
  const _SkeletonCardContent({required this.maxHeight});

  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (maxHeight < 56) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonLoader(height: 12, width: 64),
          SizedBox(height: AppSpacing.xs),
          SkeletonLoader(height: 20, width: 100),
        ],
      );
    }

    if (maxHeight < 100) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonLoader(height: 14, width: 80),
          SizedBox(height: AppSpacing.sm),
          SkeletonLoader(height: 24, width: 120),
        ],
      );
    }

    if (maxHeight < 150) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(height: 14, width: 80),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonLoader(height: 28, width: 140),
          const SizedBox(height: AppSpacing.md),
          SkeletonLoader(
            height: (maxHeight - 14 - AppSpacing.sm - 28 - AppSpacing.md)
                .clamp(12.0, 48.0),
            borderRadius: AppRadius.sm,
          ),
        ],
      );
    }

    final chartHeight = (maxHeight - 14 - AppSpacing.md - 32 - AppSpacing.lg)
        .clamp(40.0, 120.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLoader(height: 14, width: 80),
        const SizedBox(height: AppSpacing.md),
        const SkeletonLoader(height: 32, width: 160),
        const SizedBox(height: AppSpacing.lg),
        SkeletonLoader(height: chartHeight, borderRadius: AppRadius.md),
      ],
    );
  }
}

class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.listItemVertical),
      child: Row(
        children: [
          SkeletonLoader(
            height: AppSpacing.iconSize,
            width: AppSpacing.iconSize,
            borderRadius: AppRadius.pill,
          ),
          const SizedBox(width: AppSpacing.iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(height: 14, width: 140),
                const SizedBox(height: AppSpacing.sm),
                SkeletonLoader(height: 12, width: 90),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SkeletonLoader(height: 14, width: 56),
        ],
      ),
    );
  }
}

class SkeletonTransactionList extends StatelessWidget {
  const SkeletonTransactionList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => const SkeletonListRow(),
        ),
      ),
    );
  }
}

class SkeletonAccountList extends StatelessWidget {
  const SkeletonAccountList({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => const SkeletonListRow(),
        ),
      ),
    );
  }
}
