// T-17.2: one-off CSV importer for real historical expenses (spec §17,
// "manual entry or a CSV import script"). Run with:
//
//   dart run scripts/import_historical_expenses.dart <csv-path> [--config config/prod.json] [--yes] [--skip-invalid]
//
// CSV columns (header row required), mirroring the app's own export format
// from spec §11.11 minus the fields a brand-new row can't have yet
// (has_receipt, id):
//
//   date,time,member,amount_inr,category,payment_method,merchant,note
//   2026-06-03,19:42,Vineet,450.00,Groceries,UPI,Reliance Fresh,weekly veg
//
// - date: yyyy-MM-dd (required)
// - time: HH:mm, 24h (optional, defaults to 12:00)
// - member: must match an existing household member's display name
//   (case-insensitive)
// - amount_inr: decimal rupees, > 0 (required)
// - category / payment_method: must match existing household names
//   (case-insensitive); blank is allowed (left unset)
// - merchant / note: free text, optional
//
// You must sign in as the household admin so historical rows can be
// attributed to any member (RLS's exp_insert policy only lets a non-admin
// insert rows with their own user_id). The script never writes anything
// without an explicit confirmation prompt (or --yes), and validates every
// row before inserting any of them unless --skip-invalid is passed.

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class _Row {
  final int lineNumber;
  final String date;
  final String time;
  final String member;
  final int amountPaise;
  final String? category;
  final String? paymentMethod;
  final String merchant;
  final String note;

  _Row({
    required this.lineNumber,
    required this.date,
    required this.time,
    required this.member,
    required this.amountPaise,
    required this.category,
    required this.paymentMethod,
    required this.merchant,
    required this.note,
  });
}

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}

String? _readLine({bool hidden = false}) {
  if (hidden && stdin.hasTerminal) {
    stdin.echoMode = false;
  }
  final line = stdin.readLineSync();
  if (hidden && stdin.hasTerminal) {
    stdin.echoMode = true;
    stdout.writeln();
  }
  return line;
}

Map<String, String> _lookupByLowerName(List<Map<String, dynamic>> rows, String nameKey) {
  final map = <String, String>{};
  for (final r in rows) {
    map[(r[nameKey] as String).trim().toLowerCase()] = r['id'] as String;
  }
  return map;
}

void main(List<String> args) async {
  if (args.isEmpty) {
    _fail('Usage: dart run scripts/import_historical_expenses.dart <csv-path> '
        '[--config config/prod.json] [--yes] [--skip-invalid]');
  }

  final csvPath = args.first;
  var configPath = 'config/prod.json';
  var autoYes = false;
  var skipInvalid = false;
  for (var i = 1; i < args.length; i++) {
    switch (args[i]) {
      case '--config':
        configPath = args[++i];
        break;
      case '--yes':
        autoYes = true;
        break;
      case '--skip-invalid':
        skipInvalid = true;
        break;
      default:
        _fail('Unknown argument: ${args[i]}');
    }
  }

  final csvFile = File(csvPath);
  if (!csvFile.existsSync()) _fail('CSV file not found: $csvPath');

  final configFile = File(configPath);
  if (!configFile.existsSync()) _fail('Config file not found: $configPath');
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final supabaseUrl = config['SUPABASE_URL'] as String?;
  final supabaseAnonKey = config['SUPABASE_ANON_KEY'] as String?;
  if (supabaseUrl == null || supabaseAnonKey == null || supabaseUrl.contains('<ref>')) {
    _fail('$configPath is missing a real SUPABASE_URL/SUPABASE_ANON_KEY.');
  }

  // ── Parse and structurally validate the CSV ──────────────────────────
  final raw = csvFile.readAsStringSync();
  final table = Csv().decode(raw);
  if (table.isEmpty) _fail('CSV is empty.');

  final header = table.first.map((c) => c.toString().trim().toLowerCase()).toList();
  const required = ['date', 'member', 'amount_inr'];
  for (final col in required) {
    if (!header.contains(col)) _fail('CSV header is missing required column "$col".');
  }
  int colIndex(String name) => header.indexOf(name);

  final rows = <_Row>[];
  final parseErrors = <String>[];
  for (var i = 1; i < table.length; i++) {
    final lineNumber = i + 1; // 1-indexed, +1 for the header row
    final cols = table[i];
    if (cols.length == 1 && cols.first.toString().trim().isEmpty) continue; // blank line

    String col(String name) {
      final idx = colIndex(name);
      if (idx == -1 || idx >= cols.length) return '';
      return cols[idx].toString().trim();
    }

    final date = col('date');
    final dateOk = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date);
    if (!dateOk) {
      parseErrors.add('Line $lineNumber: invalid or missing date "$date" (expected yyyy-MM-dd).');
      continue;
    }

    var time = col('time');
    if (time.isEmpty) time = '12:00';
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      parseErrors.add('Line $lineNumber: invalid time "$time" (expected HH:mm).');
      continue;
    }

    final member = col('member');
    if (member.isEmpty) {
      parseErrors.add('Line $lineNumber: missing member.');
      continue;
    }

    final amountStr = col('amount_inr');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      parseErrors.add('Line $lineNumber: invalid amount_inr "$amountStr" (must be a positive number).');
      continue;
    }
    final amountPaise = (amount * 100).round();

    final category = col('category');
    final paymentMethod = col('payment_method');
    final merchant = col('merchant');
    final note = col('note');

    rows.add(_Row(
      lineNumber: lineNumber,
      date: date,
      time: time,
      member: member,
      amountPaise: amountPaise,
      category: category.isEmpty ? null : category,
      paymentMethod: paymentMethod.isEmpty ? null : paymentMethod,
      merchant: merchant,
      note: note,
    ));
  }

  if (parseErrors.isNotEmpty) {
    stderr.writeln('${parseErrors.length} row(s) failed structural validation:');
    for (final e in parseErrors) {
      stderr.writeln('  - $e');
    }
    if (!skipInvalid) {
      _fail('Fix the CSV and re-run, or pass --skip-invalid to import the rest anyway.');
    }
  }

  if (rows.isEmpty) _fail('No valid rows to import.');

  // ── Sign in ────────────────────────────────────────────────────────
  stdout.write('Admin email: ');
  final email = _readLine()?.trim() ?? '';
  stdout.write('Password: ');
  final password = _readLine(hidden: true)?.trim() ?? '';
  if (email.isEmpty || password.isEmpty) _fail('Email and password are required.');

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  try {
    await client.auth.signInWithPassword(email: email, password: password);
  } catch (e) {
    _fail('Sign-in failed: $e');
  }
  final myId = client.auth.currentUser!.id;

  final profile = await client.from('profiles').select('household_id, role, display_name').eq('id', myId).single();
  final householdId = profile['household_id'] as String?;
  final isAdmin = profile['role'] == 'admin';
  if (householdId == null) _fail('Signed-in account has no household.');
  if (!isAdmin) {
    stdout.writeln(
        'Warning: signed in as a non-admin. Only rows whose "member" matches your own '
        'display name ("${profile['display_name']}") can be imported — RLS rejects the rest.');
  }

  // ── Resolve lookups against the real household ────────────────────
  final members = await client.from('profiles').select('id, display_name').eq('household_id', householdId);
  final categories = await client.from('categories').select('id, name').eq('household_id', householdId);
  final paymentMethods = await client.from('payment_methods').select('id, name').eq('household_id', householdId);

  final memberByName = _lookupByLowerName((members as List).cast<Map<String, dynamic>>(), 'display_name');
  final categoryByName = _lookupByLowerName((categories as List).cast<Map<String, dynamic>>(), 'name');
  final paymentMethodByName = _lookupByLowerName((paymentMethods as List).cast<Map<String, dynamic>>(), 'name');

  final toInsert = <Map<String, dynamic>>[];
  final lookupErrors = <String>[];
  for (final r in rows) {
    final userId = memberByName[r.member.toLowerCase()];
    if (userId == null) {
      lookupErrors.add('Line ${r.lineNumber}: no household member named "${r.member}".');
      continue;
    }
    if (!isAdmin && userId != myId) {
      lookupErrors.add('Line ${r.lineNumber}: non-admin cannot import an expense for "${r.member}".');
      continue;
    }
    String? categoryId;
    if (r.category != null) {
      categoryId = categoryByName[r.category!.toLowerCase()];
      if (categoryId == null) {
        lookupErrors.add('Line ${r.lineNumber}: no category named "${r.category}".');
        continue;
      }
    }
    String? paymentMethodId;
    if (r.paymentMethod != null) {
      paymentMethodId = paymentMethodByName[r.paymentMethod!.toLowerCase()];
      if (paymentMethodId == null) {
        lookupErrors.add('Line ${r.lineNumber}: no payment method named "${r.paymentMethod}".');
        continue;
      }
    }

    toInsert.add({
      'id': _uuid.v4(),
      'household_id': householdId,
      'user_id': userId,
      'amount_paise': r.amountPaise,
      'category_id': categoryId,
      'payment_method_id': paymentMethodId,
      'spent_at': '${r.date}T${r.time}:00+05:30',
      'note': r.note,
      'merchant': r.merchant,
      'created_by_device': 'csv-import-script',
    });
  }

  if (lookupErrors.isNotEmpty) {
    stderr.writeln('${lookupErrors.length} row(s) failed lookup validation:');
    for (final e in lookupErrors) {
      stderr.writeln('  - $e');
    }
    if (!skipInvalid) {
      _fail('Fix the CSV (member/category/payment_method names must match the household exactly) '
          'and re-run, or pass --skip-invalid to import the rest anyway.');
    }
  }

  if (toInsert.isEmpty) _fail('No valid rows to import after lookup validation.');

  final totalPaise = toInsert.fold<int>(0, (sum, r) => sum + (r['amount_paise'] as int));
  stdout.writeln('\nReady to import ${toInsert.length} expense(s), '
      'totalling ₹${(totalPaise / 100).toStringAsFixed(2)}, '
      'into household $householdId.');
  if (!autoYes) {
    stdout.write('Continue? [y/N] ');
    final confirm = _readLine()?.trim().toLowerCase();
    if (confirm != 'y' && confirm != 'yes') {
      stdout.writeln('Aborted, nothing was written.');
      exit(0);
    }
  }

  var inserted = 0;
  final insertErrors = <String>[];
  const chunkSize = 50;
  for (var i = 0; i < toInsert.length; i += chunkSize) {
    final chunk = toInsert.sublist(i, i + chunkSize > toInsert.length ? toInsert.length : i + chunkSize);
    try {
      await client.from('expenses').insert(chunk);
      inserted += chunk.length;
    } catch (e) {
      // Fall back to per-row inserts so one bad row in a chunk doesn't
      // silently drop the rest of that chunk.
      for (final row in chunk) {
        try {
          await client.from('expenses').insert(row);
          inserted++;
        } catch (rowError) {
          insertErrors.add('id=${row['id']} spent_at=${row['spent_at']}: $rowError');
        }
      }
    }
  }

  stdout.writeln('\nDone: $inserted inserted, ${insertErrors.length} failed.');
  for (final e in insertErrors) {
    stderr.writeln('  - $e');
  }
  exit(insertErrors.isEmpty ? 0 : 1);
}
