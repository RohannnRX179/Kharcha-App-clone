import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/sync_banner.dart';

/// Bottom-nav shell for the 4 main tabs (spec §10.2). A centre FAB on
/// Dashboard/Expenses opens Add Expense; long-press opens Add Income.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _labels = ['Dashboard', 'Expenses', 'Analytics', 'Settings'];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.receipt_long_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final showFab = navigationShell.currentIndex <= 1;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: showFab
          ? _NeonFab(
              onTap: () => context.push('/expense/new'),
              onLongPress: () => context.push('/income/new'),
            )
          : null,
      bottomNavigationBar: _GlassNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// FAB with neon glow effect
class _NeonFab extends StatelessWidget {
  const _NeonFab({required this.onTap, required this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Tooltip(
        message: 'Add expense (long-press for income)',
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.mintGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.neonMint.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.neonCyan.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.ink,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass-effect navigation bar with neon indicator
class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _labels = AppShell._labels;
  static const _icons = AppShell._icons;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationDestination(
                icon: Icon(_icons[i]),
                label: _labels[i],
              ),
          ],
        ),
      ),
    );
  }
}
