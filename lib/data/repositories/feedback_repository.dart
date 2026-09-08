import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import '../../domain/models/enums.dart';
import '../remote/feedback_remote_ds.dart';
import '../remote/supabase_client_provider.dart';

part 'feedback_repository.g.dart';

/// Feedback (spec F-17, T-M3.2): a single insert into `feedback`, never
/// queued through the outbox — spec's own design ("Reading it. The owner
/// queries `feedback`... in the Supabase dashboard") assumes it always
/// reaches the server directly, and a fire-and-forget local queue would
/// mean a submission the user believes went through silently vanishing on
/// an app reinstall/cache-clear before it ever synced.
class FeedbackRepository {
  FeedbackRepository(this._client, this._remote);

  final SupabaseClient _client;
  final FeedbackRemoteDataSource _remote;

  Future<Result<void, Failure>> submit({
    required int? rating,
    required FeedbackCategory category,
    required String message,
    String? householdId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(AuthFailure('Sign in again to continue.'));
    }
    try {
      final info = await PackageInfo.fromPlatform();
      await _remote.insert({
        'user_id': userId,
        'household_id': householdId,
        'rating': rating,
        'category': category.name,
        'message': message,
        'app_version': '${info.version}+${info.buildNumber}',
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      return const Result.ok(null);
    } catch (error) {
      final failure = ErrorMapper.map(error);
      if (failure is NetworkFailure) {
        return const Result.err(
          NetworkFailure('Sending feedback needs an internet connection.'),
        );
      }
      return Result.err(failure);
    }
  }
}

@Riverpod(keepAlive: true)
FeedbackRepository feedbackRepository(Ref ref) => FeedbackRepository(
  ref.watch(supabaseClientProvider),
  ref.watch(feedbackRemoteDataSourceProvider),
);
