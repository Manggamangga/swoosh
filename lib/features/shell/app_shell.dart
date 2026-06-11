import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  bool _canPopApp(BuildContext context) {
    final router = GoRouter.of(context);
    return navigationShell.currentIndex == 0 && !router.canPop();
  }

  void _handlePop(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPopApp(context),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePop(context);
      },
      child: Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: _FrostedNavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }
}

class AnimatedBranchStack extends StatelessWidget {
  const AnimatedBranchStack({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (index) {
        final isActive = index == currentIndex;
        return _BranchFadeTransition(
          visible: isActive,
          child: children[index],
        );
      }),
    );
  }
}

class _BranchFadeTransition extends StatefulWidget {
  const _BranchFadeTransition({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<_BranchFadeTransition> createState() => _BranchFadeTransitionState();
}

class _BranchFadeTransitionState extends State<_BranchFadeTransition> {
  late bool _onStage;

  @override
  void initState() {
    super.initState();
    _onStage = widget.visible;
  }

  @override
  void didUpdateWidget(_BranchFadeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _onStage = true;
    }
  }

  void _handleFadeEnd() {
    if (!widget.visible && _onStage) {
      setState(() => _onStage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      onEnd: _handleFadeEnd,
      child: AnimatedSlide(
        offset: widget.visible ? Offset.zero : const Offset(0, 0.02),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: TickerMode(
            enabled: widget.visible,
            child: Offstage(
              offstage: !_onStage,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedNavigationBar extends StatelessWidget {
  const _FrostedNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 72,
            indicatorColor: AppColors.primary.withValues(alpha: 0.2),
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance),
                label: 'Accounts',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: 'Spending',
              ),
              NavigationDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: 'Planning',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
