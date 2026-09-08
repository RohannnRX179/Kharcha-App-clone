# Kharcha — Family Expense Tracker

A private, cross-platform household expense tracker for a five-member family,
built with Flutter and a hosted Supabase backend (Postgres + Auth + Storage +
Realtime). Every member logs their own expenses offline-first; everything
syncs to one shared household database and rolls up into household- and
per-member dashboards, budgets, recurring bills, receipts, and exports.

Private sideload only — there is no Play Store or App Store listing.

## Docs

- [`docs/SPEC.md`](docs/SPEC.md) — the full technical specification and
  phased build plan this project is built against. Read this first for any
  question about *what* the app should do.
- [`docs/PROGRESS.md`](docs/PROGRESS.md) — task-by-task build log, one row
  per task/gate, in build order.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — rationale for every non-obvious
  implementation choice and every bug found along the way, in build order.
- [`INSTALL.md`](INSTALL.md) — sideload install instructions to hand a
  friend, in plain (non-technical) language.
- [`docs/ONBOARDING.md`](docs/ONBOARDING.md) — the message template for
  inviting a friend, plus the rollout-ring order (§16.4) and the three
  questions friends actually ask.
- [`docs/legal/PRIVACY.md`](docs/legal/PRIVACY.md) /
  [`docs/legal/TERMS.md`](docs/legal/TERMS.md) — source content for the
  published privacy policy and terms (the `gh-pages` branch has the live
  HTML versions of these).

## Getting started

Flutter version is pinned via [FVM](https://fvm.app/) — see
`.fvm/fvm_config.json`. Install dependencies and run:

```sh
fvm flutter pub get
fvm flutter pub run build_runner build   # generates .g.dart / .freezed.dart
```

The app needs Supabase credentials passed as dart-defines. Copy
`config/example.json` to `config/dev.json` (gitignored) and fill in your own
project's URL and publishable key, then:

```sh
fvm flutter run --dart-define-from-file=config/dev.json
```

Run the test suite and static analysis with:

```sh
fvm flutter test
fvm flutter analyze --fatal-infos
```

Supabase schema migrations live in `supabase/migrations/` — see
`docs/PROGRESS.md`'s Phase 1 entries for how they were applied.

## Owner maintenance (monthly, spec T-M3.8)

Once real users' data is in the database, do this once a month — none of
it is automated:

1. **Check Supabase DB size and storage usage** (dashboard → Project
   Settings → Usage). Free-tier limits are generous for a household app,
   but this is the only way you'd notice before hitting one.
2. **Read new `feedback` rows** (Table Editor → `feedback`, sorted by
   `created_at`). This is the only place feedback lands — there's no
   admin UI or notification for it.
3. **Scan `last_seen_at`/`last_active_at`** (Table Editor → `profiles` /
   `households`). A household that's gone quiet for a long stretch is
   worth a check-in; an account that's never signed in past onboarding is
   worth following up on directly.
4. **Take a full backup.** Supabase's free tier doesn't guarantee
   point-in-time recovery — from any account, Settings → Data → Export
   (full backup JSON), and stash it in Google Drive. Don't rely on anyone
   else remembering to do this.
