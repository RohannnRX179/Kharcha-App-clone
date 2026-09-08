import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_provider.dart';

part 'feedback_remote_ds.g.dart';

/// Thin wrapper over the one `feedback` insert (spec F-17, T-M3.2) — its
/// own seam, like every other remote data source in this app, so
/// `FeedbackRepository` can be unit tested without mocking Postgrest's
/// builder-returning `insert()` chain directly (same rationale T-M2.2 used
/// for `HouseholdRemoteDataSource` over mocking `SupabaseClient.rpc()`).
class FeedbackRemoteDataSource {
  FeedbackRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<void> insert(Map<String, Object?> row) async {
    await _client.from('feedback').insert(row);
  }
}

@Riverpod(keepAlive: true)
FeedbackRemoteDataSource feedbackRemoteDataSource(Ref ref) =>
    FeedbackRemoteDataSource(ref.watch(supabaseClientProvider));
