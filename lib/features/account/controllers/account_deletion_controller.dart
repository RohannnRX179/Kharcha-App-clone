import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../data/local/receipt_cache.dart';
import '../../../data/repositories/account_deletion_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/sync/sync_engine.dart';

part 'account_deletion_controller.g.dart';

/// Orchestrates F-18's delete flow: reauthenticate → call the Edge Function
/// → on success, wipe every local trace and sign out (spec: "wipe local
/// storage, sign out, and show a plain confirmation screen"). `keepAlive:
/// true` for the same reason as `SignOutController`: the deletion's own
/// sign-out flips the session to null mid-call, which fires the router
/// redirect and could tear down an auto-dispose provider before
/// `wipeAll()` finishes.
@Riverpod(keepAlive: true)
class AccountDeletionController extends _$AccountDeletionController {
  @override
  FutureOr<void> build() {}

  Future<Result<void, Failure>> deleteAccount(String password) async {
    state = const AsyncLoading();
    final repo = ref.read(accountDeletionRepositoryProvider);

    final reauth = await repo.reauthenticate(password);
    if (reauth.isErr) {
      state = const AsyncData(null);
      return reauth;
    }

    // Stop the sync engine before the destructive call: an in-flight
    // push/pull racing the local wipe below is the same class of problem
    // `SignOutController` already guards against.
    final engine = ref.read(syncEngineProvider);
    engine.stop();

    final result = await repo.deleteAccount();
    if (result.isErr) {
      // Refused (e.g. promote_someone_first) — the account is still valid
      // and signed in, so re-arm sync rather than leaving it stopped.
      engine.start();
      state = const AsyncData(null);
      return result;
    }

    await ref.read(authRepositoryProvider).signOut();
    await ref.read(appDatabaseProvider).wipeAll();
    await clearReceiptCache();
    state = const AsyncData(null);
    return result;
  }
}
