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
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
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
          ? GestureDetector(
              onLongPress: () => context.push('/income/new'),
              child: Tooltip(
                message: 'Add expense (long-press for income)',
                child: Material(
                  color: Colors.transparent,
                  elevation: 5,
                  shape: const CircleBorder(),
                  child: Ink(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.green, AppColors.greenDeep],
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('/expense/new'),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.ink,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: [
              for (var i = 0; i < _labels.length; i++)
                NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
            ],
          ),
        ),
      ),
    );
  }
}
