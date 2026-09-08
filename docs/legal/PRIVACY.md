# Kharcha — Privacy Policy

*Last updated: 2026-09-08*

Kharcha is a private, invite-only household expense tracker. It is not a
commercial product and is not distributed through any app store. This
policy explains what the app collects, where it lives, and who can see it.

## What is collected

- **Account info**: your email address and the display name you choose.
- **Expense data**: every expense, income entry, budget, recurring rule,
  category, and payment method you or your household add.
- **Receipt photos**: if you attach a photo to an expense, that image is
  uploaded and stored.
- **Feedback**: if you use the in-app Feedback form, your rating, category,
  free-text message, app version, and platform (Android/iOS) are recorded
  against your account.
- **Liveness**: a single timestamp (`last_seen_at` on your account,
  `last_active_at` on your household) is updated at most once per hour
  while you use the app, so the owner can tell whether the app is actually
  being used.

**That is the entirety of usage tracking in this app.** There is no
analytics SDK, no crash reporter, no event stream, and no device
fingerprinting of any kind.

## Where it is stored

Everything above is stored in a single Supabase project (PostgreSQL,
Authentication, and Storage) hosted in the `ap-south-1` (Mumbai) region.
Receipt photos are kept in a private storage bucket, never a public one.

## Who can see it

- **Your household.** Every other member of your household can see the
  expenses, income, and budgets you add — that is the whole point of a
  shared household tracker. Nobody outside your household can see any of
  it: this is enforced by database-level access rules (Row Level
  Security), not just by the app's own screens.
- **The app's owner**, as the operator of the Supabase project this data
  lives in, has the technical ability to access the underlying database.
  The owner does not sell, share, or use your data for any purpose other
  than running and maintaining the app, and does not paste real rows of
  your data into any third-party tool or service.
- **Nobody else.** Your data is never sold, shared with advertisers, or
  handed to any third-party analytics or marketing service.

## Retention and deletion

Ordinary edits and deletes (e.g. deleting an expense) are soft-deletes —
the row is marked deleted and kept for up to 90 days so it can be
recovered if you change your mind or hit an app bug, then removed for
good.

**Deleting your account is different: it is immediate and permanent.**
From Settings → Delete account, you can export a full copy of everything
you personally added before deleting, then confirm the deletion. Deleting
your account permanently and immediately removes: your account, and every
expense, income, budget, recurring rule, and receipt you added. Other
members' entries in your household are not affected. This is not a soft
delete — once done, it cannot be undone or recovered by the owner.

## Your rights

You can, at any time, from inside the app:
- Export a full copy of the data you personally added (Settings → Data →
  Export my data).
- Delete your account and everything you added (Settings → Delete
  account).

Both of these are entirely self-service — you never need to ask the
owner, and the owner never needs `adb`, a cable, or direct database access
to do it for you.

## Contact

Questions about this policy, or about your data, can be sent to
**vineetiimabc@gmail.com**.
