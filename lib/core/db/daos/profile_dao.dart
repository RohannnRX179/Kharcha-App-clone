import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/profiles_table.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Stream<Profile?> watchById(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Every member of the household, active first then by name — the "Paid
  /// by" selector (spec §11.2) and the Expense List's member filter/name
  /// chip (spec §11.3).
  Stream<List<Profile>> watchAll(String householdId) {
    return (select(profiles)
          ..where((t) => t.householdId.equals(householdId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isActive),
            (t) => OrderingTerm.asc(t.displayName),
          ]))
        .watch();
  }

  /// Every profile this device has ever cached, regardless of current
  /// household membership — includes a departed member's row (their
  /// `household_id` goes null on leaving, but the row itself is kept per
  /// `profile_visible_to_me()`'s RLS design so their name still renders on
  /// old transactions; see docs/DECISIONS.md, "Profiles-tombstone gap").
  /// For *display* lookups only (payer/receiver names, historical exports);
  /// member-selection UI must keep using [watchAll], scoped to the current
  /// household, since you can't attribute a new row to someone who's left.
  Stream<List<Profile>> watchAllKnown() => select(profiles).watch();

  Future<Profile?> findById(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ProfilesCompanion entry) =>
      into(profiles).insertOnConflictUpdate(entry);

  Future<void> markSynced(String id) =>
      (update(profiles)..where((t) => t.id.equals(id))).write(
        const ProfilesCompanion(
          isDirty: Value(false),
          syncStatus: Value('synced'),
        ),
      );

  /// Like [markSynced], but also stamps the compare-and-swap base to
  /// [baseUpdatedAt] (the value this device just successfully pushed) —
  /// used by `pushUpsert`'s conflict-resolution path (see docs/DECISIONS.md,
  /// Gate 4 2026-09-05 fix).
  Future<void> markSyncedWithBase(String id, String baseUpdatedAt) =>
      (update(profiles)..where((t) => t.id.equals(id))).write(
        ProfilesCompanion(
          isDirty: const Value(false),
          syncStatus: const Value('synced'),
          baseUpdatedAt: Value(baseUpdatedAt),
        ),
      );

  /// Refreshes the compare-and-swap base to the server's current value
  /// without touching `isDirty`/`updatedAt` — used when a push conflict is
  /// resolved in favour of the (still-pending) local edit, so the next push
  /// attempt's compare-and-swap uses the up-to-date base.
  Future<void> updateBaseUpdatedAt(String id, String baseUpdatedAt) =>
      (update(profiles)..where((t) => t.id.equals(id))).write(
        ProfilesCompanion(baseUpdatedAt: Value(baseUpdatedAt)),
      );
}
