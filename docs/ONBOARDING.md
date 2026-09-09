# Onboarding a friend (spec §16.5.1, T-M3.7)

This is the message to send someone you're inviting to try Kharcha. Draft
it once, reuse it every time — don't improvise a new explanation per
person.

## The message

> **Install Kharcha (Android):**
> 1. Open **`<download link>`** on your phone.
> 2. Tap the APK to download it.
> 3. Android will warn about installing from this source — tap
>    **Settings**, allow it, then **Install**.
> 4. Open the app and tap **"Create an account"**.
> 5. Confirm the email it sends you (check spam if it doesn't show up in
>    a minute or two).
> 6. Create your own household, or enter code **`<invite code>`** to
>    join mine.
>
> This is a hobby app I built myself — it's not on the Play Store yet.
> You can delete your account (and everything in it) from inside the app
> whenever you like, no need to ask me.

Fill in:
- **`<download link>`** — the latest signed release APK's GitHub Release
  URL (§16.5.1: prefer a GitHub Release over a Drive link — it gives a
  stable, versioned URL, and it's what `app_releases.download_url`
  points the in-app update check at).
- **`<invite code>`** — only if you want them in *your* household. Leave
  this line out entirely if they're creating their own — don't hand out
  a code "just in case."

## Why the message says what it says (don't cut these lines)

- **"This is a hobby app I built myself... not on the Play Store yet."**
  An unexplained APK from a friend is indistinguishable from malware —
  say this plainly, every time, before they even ask.
- **"You can delete your account... whenever you like."** This is the
  self-service deletion flow (F-18) — say it up front so it's not a
  hidden feature they have to discover.
- The steps are in the order Android actually presents them (download →
  the "unknown sources" warning → install → open), not the order that
  reads best — a friend following along tap-by-tap shouldn't hit a step
  that doesn't match what's on their screen yet.

## If iPhone comes up

Say this directly rather than promising something that can't be
delivered yet:

> "Kharcha is Android-only right now. iPhone needs Apple's paid developer
> account, which I haven't bought yet — I'll let you know if that
> changes."

(See spec §16.5.2/§16.5.3 for the reasoning and what buying it would
unlock.)

## The three questions friends actually ask

Per spec §16.6's rollout-order note ("every question they ask is a defect
in copy, onboarding, or error handling — write it down and fix it before
widening"), these three come up often enough to answer here directly
rather than making each friend re-derive the answer:

1. **"I didn't get the email."** Ask them to check spam first — most
   confirmation emails that go missing are there. If it's genuinely not
   arriving, the in-app Verify Email screen has a **Resend** button
   (60-second cooldown) — no need to restart sign-up.
2. **"My code doesn't work."** Invite codes expire and are use-capped
   (spec D19) — ask the household's admin to check Household management
   → the invite section for whether it's expired, revoked, or out of
   uses, and regenerate one if needed.
3. **"How do I get my data out?"** Settings → Data → Export, or (as part
   of deleting an account) Settings → Delete account → Export my data.
   Both work offline-first from what's already synced to their phone.

## Rollout order (spec §16.4) — don't skip rings

Widen the circle one person at a time, in this order, and treat each ring
as a real gate:

| Ring | Who | Move on only once |
|---|---|---|
| 0 | You, your existing household | Nothing lost, nothing renamed after the upgrade |
| 1 | You, a second throwaway account/household | Every §7.2 cross-tenant test passes on real devices |
| 2 | 1–2 existing family members | The upgrade is invisible to them — no re-login, no re-onboarding |
| 3 | **One** friend, watched closely | They sign up, confirm, create a household, and log an expense with **no help from you** |
| 4 | 5–10 friends | Nobody reports seeing data that isn't theirs |
| 5 | The rest (< 100 accounts) | — |

Ring 3 is the one that matters: if the first friend needs your help, the
app isn't ready for the second.
