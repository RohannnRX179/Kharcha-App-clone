import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/legal_links.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/update_check_repository.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../routing/routes.dart';
import '../../auth/controllers/sign_out_controller.dart';
import 'change_password_dialog.dart';
import 'edit_profile_sheet.dart';

/// Settings hub (spec §11.13): Profile, Household, Manage, Notifications,
/// Data, About, Diagnostics.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('This clears everything stored on this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(signOutControllerProvider.notifier).signOut();
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    await ref.read(syncEngineProvider).sync();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sync complete.')));
  }

  Future<void> _clearCacheAndResync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear local cache?'),
        content: const Text(
          'Deletes everything stored on this phone and re-downloads it from '
          'the server. You stay signed in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear & re-download'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await ref.read(appDatabaseProvider).wipeAll();
    await ref.read(syncEngineProvider).sync();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared and re-synced.')),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _busy = true);
    await ref.read(updateCheckControllerProvider.notifier).check(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    final result = ref.read(updateCheckControllerProvider);
    final message = switch (result) {
      UpdateAvailable(:final release) =>
        'Version ${release.versionName} is available.',
      Blocked() => 'An update is required to keep syncing.',
      _ => "You're up to date.",
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final household = ref.watch(householdProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // ── Profile ───────────────────────────
              _SectionHeader('Profile'),
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.neonCyan,
                title: profile?.displayName ?? 'Profile',
                subtitle: profile?.isAdmin == true ? 'Admin' : 'Member',
                onTap: profile == null
                    ? null
                    : () => showEditProfileSheet(context, profile),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.neonPurple,
                title: 'Change password',
                onTap: () => showChangePasswordDialog(context),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: AppColors.danger,
                title: 'Sign out',
                onTap: _confirmSignOut,
              ),
              const _SettingsDivider(),

              // ── Household ─────────────────────────
              _SectionHeader('Household'),
              _SettingsTile(
                icon: Icons.home_outlined,
                iconColor: AppColors.neonMint,
                title: household?.name ?? '—',
                subtitle: 'Household',
                onTap: () => context.push(AppRoutes.household),
              ),
              _SettingsTile(
                icon: Icons.currency_rupee_rounded,
                iconColor: AppColors.neonAmber,
                title: 'Currency',
                subtitle: 'INR (₹)',
              ),
              const _SettingsDivider(),

              // ── Manage ────────────────────────────
              _SectionHeader('Manage'),
              _SettingsTile(
                icon: Icons.category_outlined,
                iconColor: AppColors.neonPink,
                title: 'Categories',
                onTap: () => context.push(AppRoutes.categories),
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.neonCyan,
                title: 'Payment methods',
                onTap: () => context.push(AppRoutes.paymentMethods),
              ),
              _SettingsTile(
                icon: Icons.attach_money_rounded,
                iconColor: AppColors.neonMint,
                title: 'Income',
                onTap: () => context.push(AppRoutes.income),
              ),
              _SettingsTile(
                icon: Icons.pie_chart_outline_rounded,
                iconColor: AppColors.neonPurple,
                title: 'Budgets',
                onTap: () => context.push(AppRoutes.budgets),
              ),
              _SettingsTile(
                icon: Icons.repeat_rounded,
                iconColor: AppColors.neonAmber,
                title: 'Recurring',
                onTap: () => context.push(AppRoutes.recurring),
              ),
              const _SettingsDivider(),

              // ── Notifications ─────────────────────
              _SectionHeader('Notifications'),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                iconColor: AppColors.neonCyan,
                title: 'Notifications',
                onTap: () => context.push(AppRoutes.notificationSettings),
              ),
              const _SettingsDivider(),

              // ── Feedback ──────────────────────────
              _SectionHeader('Feedback'),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                iconColor: AppColors.neonPurple,
                title: 'Send feedback',
                onTap: () => context.push(AppRoutes.feedback),
              ),
              const _SettingsDivider(),

              // ── Data ──────────────────────────────
              _SectionHeader('Data'),
              _SettingsTile(
                icon: Icons.ios_share_rounded,
                iconColor: AppColors.neonMint,
                title: 'Export',
                onTap: () => context.push(AppRoutes.export),
              ),
              _SettingsTile(
                icon: Icons.sync_rounded,
                iconColor: AppColors.neonCyan,
                title: 'Sync now',
                onTap: _syncNow,
              ),
              _SettingsTile(
                icon: Icons.delete_sweep_outlined,
                iconColor: AppColors.danger,
                title: 'Clear local cache and re-download',
                onTap: _clearCacheAndResync,
              ),
              const _SettingsDivider(),

              // ── Account ───────────────────────────
              _SectionHeader('Account'),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                iconColor: AppColors.danger,
                title: 'Delete account',
                onTap: () => context.push(AppRoutes.account),
              ),
              const _SettingsDivider(),

              // ── About ─────────────────────────────
              _SectionHeader('About'),
              const _AboutTile(),
              _SettingsTile(
                icon: Icons.system_update_outlined,
                iconColor: AppColors.neonMint,
                title: 'Check for updates',
                onTap: _checkForUpdates,
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppColors.neonCyan,
                title: 'Privacy policy',
                onTap: () => openLegalPage(
                  context,
                  url: AppConfig.privacyPolicyUrl,
                  label: 'Privacy Policy',
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: AppColors.neonCyan,
                title: 'Terms',
                onTap: () => openLegalPage(
                  context,
                  url: AppConfig.termsUrl,
                  label: 'Terms',
                ),
              ),
              const _SettingsDivider(),

              // ── Diagnostics ───────────────────────
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.neonAmber,
                title: 'Diagnostics',
                onTap: () => context.push(AppRoutes.diagnostics),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row with a tinted icon container.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.textMuted;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
      trailing: onTap != null
          ? const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSubtle,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSubtle,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        fontSize: 11,
      ),
    ),
  );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Divider(color: AppColors.outline.withValues(alpha: 0.3)),
  );
}

/// App version/build + backend host (spec §11.13 "About" — a literal
/// Supabase *region* isn't available from `AppConfig`, so the project's
/// host stands in for it; see docs/DECISIONS.md).
class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'unknown';
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? '…'
            : '${info.version} (${info.buildNumber})';
        return _SettingsTile(
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.neonPurple,
          title: 'Kharcha $version',
          subtitle: 'Backend: $host',
        );
      },
    );
  }
}
