# Release notes

## v2.0.0 build 2 (2026-09-08)

Fixes a packaging bug in build 1 (below) that silently broke sign-in for
everyone — build 1 was never distributed beyond this repo. If you somehow
already have build 1, please update.

## v2.0.0 (2026-09-08)

The first release anyone outside the Panicker family can install and use on
their own.

**What's new**
- **Sign up and create your own household** — Kharcha is no longer limited
  to one hardcoded family. Create a household and invite others with a
  code, or join one you were invited to.
- **Invite codes** — share an 8-character code (or a link) to bring someone
  into your household; regenerate or revoke it any time from Household
  management.
- **Leave / manage your household** — admins can promote, deactivate, or
  remove members; anyone can leave.
- **Send feedback** — a Feedback screen (Settings, or from Diagnostics)
  goes straight to the developer.
- **Delete your account** — Settings → Account lets you export your data
  and permanently delete your account and everything you added, without
  affecting your household-mates.
- **Privacy policy & terms** — published and linked from the sign-up
  screen and Settings → About.

**Everything from v1.0 is unchanged**: offline-first expense/income
tracking, budgets, recurring bills, receipts, analytics, exports, and
notifications all work exactly as before — this release just makes the
app usable by more than one family.

**Known limitations**
- Android only for now — iOS requires the developer's own Mac and Apple ID
  to install, so it isn't sideloadable by anyone else yet.
- If you leave a household, other members may still see your name on your
  old expenses/receipts for a little while until their app resyncs.
