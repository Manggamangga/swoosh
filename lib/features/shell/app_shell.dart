import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/haptics.dart';
import 'package:swoosh/providers/data_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _didWarmProviders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmShellProviders());
  }

  void _onDestinationSelected(int index) {
    AppHaptics.selection();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  bool _canPopApp(BuildContext context) {
    final router = GoRouter.of(context);
    return widget.navigationShell.currentIndex == 0 && !router.canPop();
  }

  void _handlePop(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (widget.navigationShell.currentIndex != 0) {
      widget.navigationShell.goBranch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPopApp(context),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePop(context);
      },
      child: ScaffoldMessenger(
        child: Scaffold(
          extendBody: true,
          body: widget.navigationShell,
          bottomNavigationBar: _FrostedNavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
          ),
        ),
      ),
    );
  }

  void _warmShellProviders() {
    if (_didWarmProviders) return;
    _didWarmProviders = true;
    ref.read(accountsProvider);
    ref.read(categoriesProvider);
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

class _BranchFadeTransition extends StatelessWidget {
  const _BranchFadeTransition({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !visible,
        child: TickerMode(
          enabled: visible,
          child: child,
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
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Insights',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
