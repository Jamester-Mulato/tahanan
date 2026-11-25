# Development journal — Appendix C

**Student:** Jamester C. Mulato · **Student No.:** 241-00315
**System:** Tahanan — Boarding House Tenant & Rent System

> Honest note: most of the app (boarding houses, rooms, tenants, rent status,
> announcements) was built before the handout was released. The security layer
> was rebuilt to the handout afterwards. The weekly entries below describe the
> work, not a fabricated commit history; the Git requirement is listed as a
> remaining process task in `handout-checklist.md`.

## Week 1 — 19–25 October 2026

**What I built.** Chose Tahanan, a boarding-house management system for owners
and tenants. Wrote the proposal and the field list: tenants need accounts to see
rent, rooms keep personal data, and owners store government IDs, so the system
qualifies. Designed the first database schema in PostgreSQL.

**Where I got stuck.** Choosing a system that stores sensitive data without
being a clone of the handout examples. I settled on tenancy records and a
government-ID field, which is sensitive personal information under RA 10173.

**How I solved it.** Mapped each field to a purpose and a rule before writing
code, which later became the privacy note and the error-message table.

**What I learned about security.** Data minimisation: if a field has no purpose,
it should not be collected at all.

**Commits this week:** 0 in this repository (proposal and schema were drafted
separately).

## Week 2 — 26 October – 1 November 2026

**What I built.** Flutter project, Express API, sign-up and Google sign-in,
refresh tokens, hashed passwords with scrypt, the users/boarding-house/room
schema, and the first version of the lockout.

**Where I got stuck.** Storing sessions safely on Android while also supporting
Flutter web. Cookies behaved differently on each platform.

**How I solved it.** Used a short-lived JWT access token plus a rotating refresh
token, both kept in secure storage on the device and never in a cookie.

**What I learned about security.** Token lifetime is a trade-off: short enough
to limit theft, long enough not to annoy the user. Refresh rotation gives both.

**Commits this week:** 0 in this repository (the app was a separate prototype).

## Week 3 — 2–8 November 2026

**What I built.** Rebuilt authentication to the handout: username-first login,
server-issued CAPTCHA with Google reCAPTCHA v2 as the primary check, 6-digit
e-mail OTP for registration / login / reset, seeded questions Q6/Q1/Q3,
forgot-password with a single-use reset grant, password history, honeypot,
AES-256-GCM for the Government ID, and the append-only `auth_events` log.

**Where I got stuck.** Making the OTP flow testable without spamming a real
inbox, and making the CAPTCHA work inside an Android WebView. I also had a
PostgreSQL service that would not start after a reboot.

**How I solved it.** Wrote `scripts/auth-e2e.mjs` and `scripts/verify-handout.ts`
to drive the API directly; used a dedicated Gmail address with plus-addressing;
repaired the PostgreSQL data directory and set the service to start
automatically. The CAPTCHA widget runs in a page served by Express so the secret
key never reaches the client.

**What I learned about security.** Enumeration is subtle: the shape of an error,
its status code, and how long it takes can all leak whether an account exists.
Identical messages plus a dummy hash closed that.

**Commits this week:** 0 in this repository (work done in the working tree).

## Week 4 — 9–16 November 2026

**What I built.** Admin security dashboard as a Flutter screen, `/api/admin/security`
JSON endpoint, the four-pattern monitoring script, CSRF origin guard, idle
timeout on both server and client, activity-log `username_typed` column,
security headers, error log outside the served tree, test accounts, SQL dump,
and the compliance documents in `backend/docs/`.

**Where I got stuck.** The dashboard refreshed every 60 seconds and filled the
log with its own `ADMIN_VIEWED_DASHBOARD` rows, and the client-side idle timer
kept firing while the app was in the background.

**How I solved it.** The refresh call passes `log=0`; only the first load writes
an event. The idle guard only runs while a session exists and resets on real
pointer input; the server's `last_activity_at` remains the authority.

**What I learned about security.** Logging can be a denial-of-service against
your own dashboard, and client timers are hints, not enforcement — the server
must always decide.

**Commits this week:** 0 in this repository (not yet initialised). Creating at
least 30 commits across four weeks is the remaining process task.

## Reflection

The hardest part was not any single feature but keeping the handout's page-based
rules meaningful in a mobile app. Every rule that protects data (validation,
lockout, OTP, idle timeout, authorisation) lives on the server; the app only
mirrors the messages. That is why the system still behaves correctly when the
client is modified.
