# Phase M2 tester checklist

This is for whoever is doing a fresh-eyes test pass on Phase M2 (multi-user
households). You don't need to read `PROGRESS.md`/`DECISIONS.md` — those are
build logs for the developer, not a test script. This file is the test
script. Everything below is either genuinely never tested on a real device
yet, or was tested once and needs a second look after a bug fix.

**Do not use the real Panicker family household for any of this.** Sign up
as a brand-new user with your own email and create your own throwaway
household — steps 1–2 below walk through that. Nothing here should touch
Vineet's real data.

Work through the sections in order and fill in the Result column as you go
(✅ pass / ❌ fail / ⚠️ works but looks off). For anything that fails, write
down: what you tapped, what you expected, what actually happened. A
screenshot or screen recording is even better than a description if
something visually breaks.

When you're done, commit your results to this file and open a PR.

---

## 1. Sign-up with real email confirmation

This has never been tested end-to-end on a real device — it needs an actual
inbox and a human clicking a link, which is exactly what an automated test
can't do.

| # | Step | Result | Notes |
|---|------|--------|-------|
| 1.1 | Open the app for the first time. You should land on a Login screen with a "New here? Create an account" link. | | |
| 1.2 | Tap it, fill in display name / email / password (min 8 characters), confirm password, tap Create account. | | |
| 1.3 | You should land on a "check your email" screen showing the address you signed up with. | | |
| 1.4 | Go check that inbox for real (may take a minute; check spam). Tap the confirmation link. | | |
| 1.5 | Without you doing anything else in the app, it should notice the confirmation and move on by itself (it polls in the background) — you shouldn't need to manually refresh or restart. | | |
| 1.6 | After confirming, you should land on an onboarding screen with two options: Create a household / Join a household. | | |

## 2. Create your own household

| # | Step | Result | Notes |
|---|------|--------|-------|
| 2.1 | Tap Create a household. The name field should be prefilled with something like "`<your name>`'s household" — you can change it or just continue. | | |
| 2.2 | After creating, the same screen should flip to show an invite code (something like `ABCD-EFGH`), with Copy and Share buttons. | | |
| 2.3 | Tap "I'll do this later" — you should land on the Dashboard, empty (no expenses yet). | | |

## 3. Basic usage (the everyday screens)

Spend a few minutes actually using the app like a real user would — this is
the widest-coverage, lowest-effort part of testing. Add a few of each:

| # | Step | Result | Notes |
|---|------|--------|-------|
| 3.1 | Add a couple of expenses (different categories, payment methods). | | |
| 3.2 | Add an income entry. | | |
| 3.3 | Set a budget for a category. | | |
| 3.4 | Set up a recurring expense/income rule. | | |
| 3.5 | Check the Dashboard reflects what you added correctly (totals, charts). | | |
| 3.6 | Try the Export feature (full backup / CSV, whatever's offered). | | |
| 3.7 | Check Notification settings — toggle something, see if it sticks. | | |
| 3.8 | Look at the About screen — just confirm it renders without crashing. | | |

None of this is new to Phase M2, but it's never been run against a
multi-tenant (household-scoped) account before, so it's worth a sanity pass.

## 4. Household management screen

Settings → Household.

| # | Step | Result | Notes |
|---|------|--------|-------|
| 4.1 | Confirm you see: household name, member count, "Created `<date>`". | | |
| 4.2 | As the only member, you should be admin — try renaming the household inline. | | |
| 4.3 | Invite section: confirm the code, expiry, and use-count line render. | | |
| 4.4 | Tap Regenerate — confirm dialog appears, new code replaces the old one. | | |
| 4.5 | Tap Revoke — confirm the invite goes away / becomes unusable. | | |
| 4.6 | Regenerate a fresh invite again (you'll need it for section 5). | | |

## 5. Invite / join with a second account

This needs a second email address — a spare Gmail alias, a friend, whatever
you've got. If you can, use a second device or a second app install so both
accounts can be live at once; otherwise you can sign out/in between the two.

| # | Step | Result | Notes |
|---|------|--------|-------|
| 5.1 | On the second account, sign up fresh (same flow as section 1). | | |
| 5.2 | On the onboarding screen, tap "Join a household" and enter the invite code from 4.6. Confirm the code field auto-uppercases and formats as you type. | | |
| 5.3 | You should see "You've joined `<household name>`" then land on the Dashboard, now showing the first account's expenses. | | |
| 5.4 | Back on account 1: check the household management screen — the new member should now appear in the members list (may need "Sync now" or a moment). | | |
| 5.5 | As admin (account 1), open the second member's overflow menu — try "Make admin", then "Make member" again. | | |
| 5.6 | Try Deactivate on the second member, then Reactivate. Confirm the member re-sorts to the bottom while inactive and back when reactivated. | | |

## 6. Leave / rejoin — the flow that was just fixed

**This is the most important section.** Two bugs were found live-testing
this exact flow and have just been fixed in code, but never re-tested on a
real device. If anything here goes wrong, that's the single highest-value
thing to report back.

| # | Step | Result | Notes |
|---|------|--------|-------|
| 6.1 | On account 2 (the member, not the admin), go to Household → Leave household. Confirm the warning dialog text, then confirm. | | |
| 6.2 | You should land back on the onboarding screen (Create/Join), **not** stay on the Dashboard. | | |
| 6.3 | On account 1 (admin), after a sync, the member you removed should disappear from the household members list. | | |
| 6.4 | On account 2, rejoin using the same or a fresh invite code from account 1. Confirm you land back on the Dashboard with the household's data visible again. | | |
| 6.5 | **Sign out on account 2, then sign back in.** Add a new expense. Confirm it actually shows up on account 1 after a sync (i.e. sync is still working after the sign-out/sign-in — this was the second bug: sync used to silently stop working forever after any sign-out). | | |

## 7. Remove a member / delete a household

Only do this at the very end, since it's destructive to the test household
you made in section 2 — not the real family one.

| # | Step | Result | Notes |
|---|------|--------|-------|
| 7.1 | As admin, use the overflow menu to Remove the other member (rather than have them leave). Confirm the consequence-warning dialog text, then confirm. | | |
| 7.2 | Once you (account 1) are the only member left, the Delete household option should appear. Tap it — confirm it offers "export a backup first". | | |
| 7.3 | Type the exact household name to confirm deletion. Confirm the household is actually gone and you land back on onboarding. | | |

---

## Reporting back

For each ❌ or ⚠️ row above, add a short note here (or inline in the Notes
column, whichever's easier) with:
- what you tapped / did
- what you expected
- what actually happened
- device/OS version you tested on

Then commit this file with your results and open a PR against `master`.
