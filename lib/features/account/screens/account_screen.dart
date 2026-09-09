import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/failure.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/export_repository.dart';
import '../../../routing/routes.dart';
import '../controllers/account_deletion_controller.dart';

/// Account & data deletion (spec §11.18 F-18, T-M3.5): a deliberately slow,
/// three-step flow — explain what goes, offer (or skip) an export, then
/// type `DELETE` and re-enter the password. The second and third steps are
/// both gated behind [_exportedOrSkipped] so the destructive fields aren't
/// even visible until the user has made a real choice about their data.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _deleteTextController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _exportedOrSkipped = false;
  bool _exporting = false;
  bool _deleting = false;
  Failure? _error;

  @override
  void dispose() {
    _deleteTextController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _deleteTextMatches =>
      _deleteTextController.text.trim().toUpperCase() == 'DELETE';

  Future<void> _exportMyData() async {
    setState(() => _exporting = true);
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final result = userId == null
        ? null
        : await ref
              .read(exportRepositoryProvider)
              .exportMyDataJson(userId: userId);
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportedOrSkipped = true;
    });
    final file = result?.valueOrNull;
    if (file != null) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?.failureOrNull?.message ?? 'Could not export your data.',
          ),
        ),
      );
    }
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    final result = await ref
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount(_passwordController.text);
    if (!mounted) return;
    result.fold((_) => context.go(AppRoutes.accountDeleted), (failure) {
      setState(() {
        _deleting = false;
        _error = failure;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Deletes your account, and every expense, income, budget, and '
            "receipt you added. Other members' entries in your household "
            'are not affected. This cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (!_exportedOrSkipped) ...[
            Text(
              'Before you go, you can export everything you added.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _exporting ? null : _exportMyData,
                    child: _exporting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Export my data'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _exporting
                      ? null
                      : () => setState(() => _exportedOrSkipped = true),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ] else ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Type DELETE to confirm, then enter your password.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deleteTextController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type DELETE',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed:
                  (_deleteTextMatches &&
                      _passwordController.text.isNotEmpty &&
                      !_deleting)
                  ? _delete
                  : null,
              child: _deleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete my account'),
            ),
          ],
        ],
      ),
    );
  }
}
