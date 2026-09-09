import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import '../remote/supabase_client_provider.dart';

part 'account_deletion_repository.g.dart';

/// Account & data deletion (spec F-18, T-M3.5). [deleteAccount] is a thin
/// wrapper over the `delete-account` Edge Function (§6.9.5, already
/// deployed and live-tested during T-M1.7) — every actual deletion/refusal
/// rule lives server-side; this only translates its named refusals into
/// [Failure]s, the same job [ErrorMapper]'s named-RPC-code handling does
/// for Postgres RPCs.
class AccountDeletionRepository {
  AccountDeletionRepository(this._client);

  final SupabaseClient _client;

  /// Re-confirms the signed-in user's password before a destructive
  /// deletion (spec F-18 step 3) — a plain `signInWithPassword` call, since
  /// GoTrue has no separate "verify without establishing a session" API and
  /// this is already the current user's own session.
  Future<Result<void, Failure>> reauthenticate(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      return const Result.err(AuthFailure('Sign in again to continue.'));
    }
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const Result.ok(null);
    } catch (error) {
      final failure = ErrorMapper.map(error);
      // Every AuthException here means one thing on this screen: the
      // password just typed is wrong — never surface sign-in's own
      // "account doesn't exist"/rate-limit wording for an already
      // signed-in user re-confirming themselves.
      if (failure is AuthFailure) {
        return const Result.err(AuthFailure('Incorrect password.'));
      }
      return Result.err(failure);
    }
  }

  Future<Result<void, Failure>> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
      return const Result.ok(null);
    } on FunctionException catch (error) {
      return Result.err(_mapDeleteError(error));
    } catch (error) {
      return Result.err(ErrorMapper.map(error));
    }
  }

  Failure _mapDeleteError(FunctionException error) {
    if (error is FunctionsFetchException) {
      return const NetworkFailure(
        'Deleting your account needs an internet connection.',
      );
    }
    // The Edge Function's own JSON error body (`{"error": "<code>"}`,
    // §6.9.5) — copy for `promote_someone_first` is spec-exact (F-18);
    // every other code it can return (`not_authenticated`,
    // `profile_not_found`, `lookup_failed`, `*_failed`) means something
    // went wrong server-side, not a rule this screen's flow can violate on
    // its own, so they fall through to the generic failure.
    final details = error.details;
    final code = details is Map ? details['error'] as String? : null;
    if (code == 'promote_someone_first') {
      return const ValidationFailure(
        "You're the only admin of your household. Make someone else an "
        'admin, or remove the other members first.',
      );
    }
    return const UnknownFailure();
  }
}

@Riverpod(keepAlive: true)
AccountDeletionRepository accountDeletionRepository(Ref ref) =>
    AccountDeletionRepository(ref.watch(supabaseClientProvider));
