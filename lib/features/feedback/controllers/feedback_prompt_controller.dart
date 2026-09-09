import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/database_provider.dart';
import '../../../data/remote/supabase_client_provider.dart';

part 'feedback_prompt_controller.g.dart';

const _dismissedKey = 'feedback_prompt_dismissed';

/// Whether the one-time Dashboard feedback prompt should show (spec F-17,
/// T-M3.3): fires once the signed-in user has saved >= 10 expenses of their
/// own (anywhere, not the household's total), and never again once
/// dismissed or answered — both paths call [dismiss], see
/// `FeedbackPromptBanner`. Loads the persisted flag once at build time,
/// same "default state until prefs resolve" precedent as
/// `NotificationSettingsController` — a false start here is harmless, since
/// the false path never nags anyone.
@Riverpod(keepAlive: true)
class FeedbackPromptController extends _$FeedbackPromptController {
  StreamSubscription<int>? _countSub;

  @override
  bool build() {
    ref.onDispose(() => _countSub?.cancel());
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) ?? false) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final db = ref.read(appDatabaseProvider);
    _countSub = db.expenseDao.watchCountByUser(userId).listen((count) {
      if (count >= 10) state = true;
    });
  }

  Future<void> dismiss() async {
    state = false;
    await _countSub?.cancel();
    _countSub = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }
}
