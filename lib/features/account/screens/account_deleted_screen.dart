import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';

/// Plain confirmation shown right after a successful account deletion
/// (spec F-18: "show a plain confirmation screen — do not drop the user
/// back at a login form as though nothing happened"). Reachable while
/// signed out (see `app_router.dart`'s `redirect`) so the router's own
/// signed-out gate doesn't bounce past it before the user has seen it.
class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your account has been deleted',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Everything you added — your account, expenses, income, '
                'budgets, and receipts — has been permanently removed. '
                "Other members' entries in your former household are "
                'unaffected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
