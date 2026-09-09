import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:kharcha/core/db/app_database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

/// Regression test for the Gate M2 leave-household bug (2026-09-07):
/// `profiles.household_id` becomes nullable, mirroring Postgres (nullable
/// since T-M1.1). Exercises the actual v7 -> v8 upgrade — which recreates
/// the table via drift's 12-step `alterTable` since SQLite can't drop a NOT
/// NULL constraint in place — against a hand-built v7 file, proving both
/// that existing rows survive and that a null household_id (as a
/// leave_household/remove_member row would have, once re-pulled) can
/// actually be written after the migration.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kharcha_migration_v8_test');
    dbPath = p.join(tempDir.path, 'kharcha.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
    'upgrading a real v7 database makes household_id nullable, keeps '
    'existing rows intact, and accepts a null household_id afterward',
    () async {
      final raw = sqlite3.sqlite3.open(dbPath);
      raw.execute('''
        CREATE TABLE households (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          currency_code TEXT NOT NULL DEFAULT 'INR',
          timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'synced',
          local_updated_at INTEGER NULL,
          is_dirty INTEGER NOT NULL DEFAULT 0,
          base_updated_at TEXT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE profiles (
          id TEXT NOT NULL PRIMARY KEY,
          household_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'member',
          colour_hex TEXT NOT NULL DEFAULT '#6750A4',
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'synced',
          local_updated_at INTEGER NULL,
          is_dirty INTEGER NOT NULL DEFAULT 0,
          base_updated_at TEXT NULL,
          joined_at INTEGER NULL
        );
      ''');
      for (final table in [
        'categories',
        'payment_methods',
        'expenses',
        'incomes',
        'budgets',
        'recurring_rules',
        'attachments',
      ]) {
        raw.execute('''
          CREATE TABLE $table (
            id TEXT NOT NULL PRIMARY KEY,
            updated_at INTEGER NOT NULL,
            is_dirty INTEGER NOT NULL DEFAULT 0,
            base_updated_at TEXT NULL
          );
        ''');
      }
      raw.execute('''
        CREATE TABLE outbox_entries (
          id TEXT NOT NULL,
          entity TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          op TEXT NOT NULL,
          payload TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT NULL,
          next_attempt_at INTEGER NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          PRIMARY KEY (id)
        );
      ''');
      raw.execute('''
        CREATE TABLE sync_meta (
          entity TEXT NOT NULL PRIMARY KEY,
          last_pulled_at INTEGER NULL,
          last_success_at INTEGER NULL,
          household_id TEXT NULL
        );
      ''');
      final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
      raw.execute(
        "INSERT INTO households (id, name, created_at, updated_at) "
        "VALUES ('hh1', 'Panicker Family', ?, ?)",
        [now, now],
      );
      raw.execute(
        'INSERT INTO profiles '
        '(id, household_id, display_name, role, created_at, updated_at) '
        "VALUES ('u1', 'hh1', 'Vineet', 'admin', ?, ?)",
        [now, now],
      );
      raw.execute('PRAGMA user_version = 7;');
      raw.close();

      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      final db = AppDatabase();
      final profiles = await db.select(db.profiles).get();

      expect(profiles, hasLength(1));
      expect(profiles.single.displayName, 'Vineet');
      expect(
        profiles.single.householdId,
        'hh1',
        reason: 'existing rows must survive the table-recreate migration',
      );

      // The whole point of the fix: a leave_household-style null must now
      // be writable, where it would previously violate the NOT NULL
      // constraint from the pre-v8 schema.
      await db.profileDao.upsert(
        ProfilesCompanion.insert(
          id: 'u1',
          householdId: const Value(null),
          displayName: 'Vineet',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final afterLeave = await db.profileDao.findById('u1');
      expect(afterLeave!.householdId, isNull);

      await db.close();
    },
  );
}
