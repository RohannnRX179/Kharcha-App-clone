// T-17.3: turns a full JSON backup (spec §11.11, `ExportRepository
// .exportFullBackupJson` / spec's own "admin-only... Re-importable by hand
// into Supabase" acceptance line for T-12.4) into a plain SQL script that
// restores every row into a target Supabase project's Postgres database,
// bypassing PostgREST/RLS entirely (this is a disaster-recovery tool, not
// a normal client — it's meant to run with a privileged connection).
//
// Usage (the target project must already have every migration in
// supabase/migrations/ applied, e.g. via `supabase db push`):
//   dart run scripts/restore_backup.dart <backup.json> > restore.sql
//   supabase link --project-ref <target-ref> --password <target-db-password>
//   supabase db query --linked -f restore.sql
//   supabase link --project-ref <ref-you-were-on-before>   # switch back!
//
// `supabase db query` only reaches an *unlinked* project via `--db-url`,
// which needs a direct Postgres connection (port 5432) that isn't always
// reachable (it wasn't from this project's own sandbox) — linking first
// and using `--linked` goes through the Management API instead and always
// works. Re-link back to whatever project you started on immediately
// after — the rest of this repo's tooling (this script's own sibling
// import_historical_expenses.dart aside) assumes the linked project is
// production.
//
// Restore order matters and is handled here:
//   1. households (upserted — see the seed-collision note below)
//   2. auth.users — one minimal row per referenced profile id, needed
//      because `profiles.id references auth.users(id)`. This fires
//      `handle_new_user()`, which inserts its own placeholder profile row
//      (`on conflict (id) do nothing`, household_id null, a display name
//      derived from the dummy email).
//   3. profiles — upserted (not `do nothing`), so the real backed-up row
//      overwrites step 2's trigger-generated placeholder.
//   4. categories, payment_methods (existing rows for this household are
//      deleted first — see below)
//   5. recurring_rules (expenses/incomes.recurring_rule_id reference it)
//   6. expenses, incomes, budgets
//   7. attachments (references expenses + profiles)
//
// Known gotcha: 0009_seed.sql always seeds household id
// 11111111-1111-1111-1111-111111111111 with its own default categories/
// payment methods (fresh random ids, same names) the moment migrations are
// pushed to any target — colliding with the real ones on
// categories_unique_name/payment_methods_unique_name. This script deletes
// any pre-existing categories/payment_methods for the backup's household
// before restoring, since the restore is meant to be authoritative for
// that household's data anyway.
//
// Known limitation: this restores database rows only. The actual receipt
// image bytes in Storage are not part of the JSON backup (spec's own
// design — "no images... keeps the file small" applies to the PDF export,
// and the JSON backup was likewise never meant to duplicate Storage), so
// restored `attachments` rows will point at storage paths with nothing
// behind them. See docs/DECISIONS.md's T-17.3 entry for the full restore
// write-up including how that gap was verified deliberately.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/restore_backup.dart <backup.json> > restore.sql');
    exit(1);
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Error: backup file not found: ${args.first}');
    exit(1);
  }
  final backup = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  final buf = StringBuffer();
  buf.writeln('begin;');
  // guard_profile_membership() (0013_multitenant_rls.sql) blocks direct
  // household_id/role changes on profiles outside create_household()/
  // join_household()/leave_household()/set_member_role() — which the
  // profiles upsert below needs to do, since handle_new_user() will have
  // just created a placeholder row with household_id null. This is its
  // documented escape hatch, not a workaround.
  buf.writeln("set local kharcha.allow_membership_change = 'on';");
  buf.writeln();

  final householdId = backup['household_id'] as String;

  // A target that already ran 0009_seed.sql (any freshly-migrated project,
  // since that migration always seeds household id
  // 11111111-1111-1111-1111-111111111111 with its own default categories/
  // payment methods) has placeholder rows that collide with the real ones
  // on categories_unique_name/payment_methods_unique_name (same names,
  // different ids) — a plain insert would fail those unique constraints
  // outright, not just skip harmlessly like `on conflict (id)` would. The
  // restore is meant to be authoritative for this household, so clear any
  // pre-existing rows for it first.
  buf.writeln('-- Clear any pre-existing seed/placeholder data for this');
  buf.writeln('-- household before restoring (see restore_backup.dart\'s');
  buf.writeln('-- top-of-file note on 0009_seed.sql\'s name collision).');
  buf.writeln("delete from public.categories where household_id = ${_sqlValue(householdId)};");
  buf.writeln("delete from public.payment_methods where household_id = ${_sqlValue(householdId)};");
  buf.writeln();

  // households.created_by is a FK to profiles(id), which doesn't exist yet
  // at this point — insert it as NULL and back-fill with an UPDATE once
  // profiles/auth.users exist below, rather than reordering the whole
  // restore around one circular reference. Upsert (not "do nothing") so a
  // pre-existing seed row's placeholder values get overwritten with the
  // real backup ones instead of silently surviving.
  _insertTable(
    buf,
    'public.households',
    backup['households'],
    conflictCol: 'id',
    nullOutColumns: {'created_by'},
    upsert: true,
  );
  // auth.users must exist BEFORE profiles (profiles.id references it), but
  // creating it fires handle_new_user(), which inserts its own placeholder
  // profile row (household_id null, a display name derived from the dummy
  // email) via `on conflict (id) do nothing` — so the real profiles insert
  // below must be an upsert, or the trigger's placeholder would win.
  _insertAuthUsers(buf, (backup['profiles'] as List).cast<Map<String, dynamic>>());
  _insertTable(buf, 'public.profiles', backup['profiles'], conflictCol: 'id', upsert: true);
  _backfillDeferredColumn(buf, 'public.households', backup['households'], column: 'created_by');
  _insertTable(buf, 'public.categories', backup['categories'], conflictCol: 'id');
  _insertTable(buf, 'public.payment_methods', backup['payment_methods'], conflictCol: 'id');
  // recurring_rules before expenses/incomes: expenses.recurring_rule_id and
  // incomes.recurring_rule_id are FKs into it.
  _insertTable(buf, 'public.recurring_rules', backup['recurring_rules'], conflictCol: 'id');
  _insertTable(buf, 'public.expenses', backup['expenses'], conflictCol: 'id');
  _insertTable(buf, 'public.incomes', backup['incomes'], conflictCol: 'id');
  _insertTable(buf, 'public.budgets', backup['budgets'], conflictCol: 'id');
  _insertTable(buf, 'public.attachments', backup['attachments'], conflictCol: 'id');

  buf.writeln('commit;');
  stdout.write(buf.toString());
}

/// Minimal-but-valid `auth.users` rows so `profiles.id references
/// auth.users(id)` is satisfiable. Email/password are throwaway — nobody
/// signs in with these on the restore target during the disaster-recovery
/// proof; the point is referential integrity, not working credentials.
void _insertAuthUsers(StringBuffer buf, List<Map<String, dynamic>> profiles) {
  buf.writeln('-- auth.users (minimal rows so profiles.id\'s FK resolves;');
  buf.writeln('-- handle_new_user() on-conflict-do-nothing leaves the real');
  buf.writeln('-- profile row above untouched)');
  for (final p in profiles) {
    final id = p['id'] as String;
    final email = 'restored-$id@restore.invalid';
    buf.writeln('insert into auth.users '
        '(id, instance_id, aud, role, email, email_confirmed_at, '
        'created_at, updated_at, raw_app_meta_data, raw_user_meta_data, '
        'is_sso_user, is_anonymous) values ('
        '${_sqlUuid(id)}, '
        "'00000000-0000-0000-0000-000000000000', "
        "'authenticated', 'authenticated', "
        '${_sqlString(email)}, now(), now(), now(), '
        '\'{"provider":"email","providers":["email"]}\'::jsonb, '
        "'{}'::jsonb, false, false"
        ') on conflict (id) do nothing;');
  }
  buf.writeln();
}

void _insertTable(
  StringBuffer buf,
  String table,
  dynamic rowsJson, {
  required String conflictCol,
  Set<String> nullOutColumns = const {},
  bool upsert = false,
}) {
  final rows = (rowsJson as List).cast<Map<String, dynamic>>();
  buf.writeln('-- $table (${rows.length} row(s))');
  if (rows.isEmpty) {
    buf.writeln();
    return;
  }
  final columns = rows.first.keys.toList();
  final conflictAction = upsert
      ? 'do update set ${columns.where((c) => c != conflictCol).map((c) => '$c = excluded.$c').join(', ')}'
      : 'do nothing';
  for (final row in rows) {
    final values = columns
        .map((c) => nullOutColumns.contains(c) ? 'NULL' : _sqlValue(row[c]))
        .join(', ');
    buf.writeln('insert into $table (${columns.join(', ')}) '
        'values ($values) on conflict ($conflictCol) $conflictAction;');
  }
  buf.writeln();
}

/// Back-fills a column that had to be nulled out in [_insertTable] (a
/// forward reference to a row inserted later), now that its target exists.
void _backfillDeferredColumn(StringBuffer buf, String table, dynamic rowsJson, {required String column}) {
  final rows = (rowsJson as List).cast<Map<String, dynamic>>();
  final withValue = rows.where((r) => r[column] != null).toList();
  if (withValue.isEmpty) return;
  buf.writeln('-- $table.$column (back-filled after its FK target exists)');
  for (final row in withValue) {
    buf.writeln('update $table set $column = ${_sqlValue(row[column])} '
        'where id = ${_sqlValue(row['id'])};');
  }
  buf.writeln();
}

String _sqlValue(dynamic v) {
  if (v == null) return 'NULL';
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return v.toString();
  return _sqlString(v.toString());
}

String _sqlUuid(String id) => '${_sqlString(id)}::uuid';

String _sqlString(String s) => "'${s.replaceAll("'", "''")}'";
