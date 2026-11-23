# IT 107 Handout — Tahanan system compliance

**System:** Tahanan — Boarding House Tenant & Rent System
**Student:** Jamester C. Mulato · **Student No.:** 241-00315
**Stack:** Flutter (Android + web) · Node/Express · PostgreSQL 18
**Where everything lives:** the app (`lib/`) and its backend (`backend/`). There is no separate project.

The handout is written for PHP/MySQL pages. This project is the same system in
Flutter + Express + PostgreSQL, so page-level wording maps to app screens and
API routes. Every mapping and every deviation is listed here and in
`handout-checklist.md`.

## 1. Seed table (student 241-00315 → D1 = 1, D2 = 5)

| Parameter | Formula | Value |
|---|---|---|
| Min username | 6 + (D1 mod 3) | **7** |
| Max username | 16 + (D2 mod 5) | **16** |
| Min password | 8 + (D2 mod 4) | **9** |
| Max name length | 20 + D2 | **25** |
| Failures before “Forgot Password” | 2 + (D1 mod 2) | **3** |
| Lockout tier 1 | 15 + D1 | **16 s** |
| Lockout tier 2 | 30 + 2×D1 | **32 s** |
| Lockout tier 3 | 60 + 4×D1 | **64 s** |
| OTP expiry | 3 + (D2 mod 3) | **5 min** |
| Idle timeout | 5 + (D1 mod 5) | **6 min** |
| IP block threshold | 8 + D2 | **13 / 10 min** |
| Questions | Q[(D2 mod 8)+1], Q[((D2+3) mod 8)+1], Q[((D2+5) mod 8)+1] | **Q6, Q1, Q3** |

Implemented in `backend/src/config/env.ts`, `backend/src/security/questions.ts`,
`backend/src/services/auth.service.ts`, `backend/src/security/registration.ts`
and `backend/src/services/login-otp.service.ts`.

## 2. System fields (four kinds)

| Field | Kind | Required | Rule | Error |
|---|---|---|---|---|
| ID Number | formatted number | yes | `xxxx-xxxx`, unique identity | ID Number must follow the format xxxx-xxxx. |
| Government ID Number | formatted number, **AES-256-GCM encrypted** | yes | `xxxx-xxxx-xxxx` | Government ID Number must follow the format xxxx-xxxx-xxxx. |
| Move-in Date | date | yes | 2000-01-01 … today | Move-in Date must be a valid date between 2000-01-01 and today. |
| Room Type | dropdown | yes | Single / Shared / Bedspacer / Studio, server-checked | Please select a valid room type. |
| Emergency Contact | phone | yes | 11 digits starting 09 | Contact number must be 11 digits and start with 09. |
| Tenancy Notes | free text | no | ≤200 chars, letters/digits/,. spaces | Tenancy Notes may contain letters, digits, commas, periods and spaces only, up to 200 characters. |

Core fields: ID Number, First / Middle / Family Name, Name Extension,
Birthdate + computed Age, six address fields, Email, Username, Password +
Re-enter Password, three seeded questions, privacy consent.

## 3. Privacy notice (RA 10173)

The registration screen has a required, unchecked-by-default consent checkbox
with the exact handout wording and a “Read the Privacy Notice” link.
`users.privacy_consent_at` stores the consent time. The same notice opens from
the sign-in screen and from More → Privacy.

Personal data: name, birthdate/age, address, email, username, tenancy details,
Government ID (sensitive personal information, encrypted), security answers
(hashed), activity log (IP, user agent).

Purpose: identity verification, tenancy management, security alerts. Retention:
while the tenancy is active plus one year. Access/correction through the
administrator. Complaints: National Privacy Commission. The full text lives in
`lib/widgets/privacy_notice.dart` and `docs/privacy-note.md`.

## 4. Authentication questions

Q6 “What was the first song you learned by heart?”, Q1 “What was the name of your
first pet?”, Q3 “Who was your favorite teacher in high school?”. Answers are 2–50
letters/spaces, lowercased and hashed with scrypt before storage
(`security_answers.answer_hash`).

## 5. OTP rules

`login_otps` stores a hashed code with `purpose` (register / login / reset),
`expires_at`, `attempts`, `used`, `resend_count`, `last_sent_at`.
6 digits from `crypto.randomInt`, 5-minute expiry, 3 wrong entries cancel the
code, single use, a new code cancels the old one, 60-second resend cooldown,
and at most 3 resends per 15 minutes per purpose.
No session or token is issued before the code is accepted.

## 6. Threat model (one row per protection)

| # | Threat | Vulnerability | Countermeasure | CIA | Tested |
|---|---|---|---|---|---|
| 1 | SQL injection | string-built SQL | parameterised queries only (`$1…`) | C,I | `' OR '1'='1` → normal “Invalid username or password.” |
| 2 | XSS | attacker text in logs | JSON API + Flutter text rendering; no HTML sink | I | `<script>alert(1)</script>` stored and rendered as text |
| 3 | CSRF | forged state change | Bearer JWT, no cookie auth; same-origin check on every POST/PATCH/PUT/DELETE; `CSRF_REJECTED` logged | I | foreign `Origin` → 403 + `CSRF_REJECTED` |
| 4 | Enumeration | different errors | identical “Invalid username or password.” + dummy scrypt; forgot flow identical for unknown users | C | unknown vs wrong password compared |
| 5 | Brute force | unlimited attempts | 3/6/9 lockout 16/32/64 s, IP block 13/10 min | A | 423 with `retryAfter` |
| 6 | Session theft | long-lived tokens | JWT + rotating refresh tokens, `token_version` bump, server idle check, client idle guard | C | 401 `SESSION_IDLE`, token dead after logout |
| 7 | Password reuse | old passwords reused | `password_history`, last 3 refused | I | “You cannot reuse a recent password.” |
| 8 | Bots | automated registration | hidden `website` honeypot + server CAPTCHA | I | honeypot → silent 201 |
| 9 | Blind attacks | no trace | `auth_events` append-only log | I | trigger blocks UPDATE/DELETE |
| 10 | Info leak | stack traces | generic 500, `logs/error.log` outside the served tree | C | invalid input → safe message |
| 11 | Secret leak | keys in repo | `.env` git-ignored; `config` not served | C | git history scanned |
| 12 | Clickjacking | framed UI | Helmet `X-Frame-Options: DENY`, `nosniff` | I | response headers verified |
| 13 | Data breach | readable sensitive field | AES-256-GCM + random IV + HMAC lookup | C | DB shows ciphertext |

Full worksheet: `docs/threat-model.md`.

## 7. Design decisions (“Your call”)

- **Hashing:** scrypt (N=16384, r=8, p=1) — memory-hard, no native build step. OTPs use the same function.
- **Password strength:** Weak / Medium / Strong. Weak (fails length, uppercase or digit) cannot be submitted on either client or server.
- **Failed CAPTCHA:** does **not** count as a failed sign-in (an attacker could otherwise lock a victim out); it is logged as `CAPTCHA_FAILED`.
- **Why hash answers:** answers are low-entropy secrets; hashing stops an SQL leak from handing over the recovery path. Lowercasing makes answers case-insensitive.
- **Change Password access:** a short-lived, single-use reset grant is issued only after the reset OTP; the app cannot open the password screen directly.
- **Back button:** disabling it is cosmetic; the server checks the JWT on every request, so history cannot reveal data.
- **Idle timeout:** enforced twice — `users.last_activity_at` in `requireAuth` (401 `SESSION_IDLE`) and `IdleSessionGuard` in the app (warning at 5 min, sign-out at 6 min).
- **Log protection:** the app’s database role never updates or deletes `auth_events`; a trigger rejects both.
- **Admin dashboard:** Flutter screen `lib/screens/admin/security_dashboard.dart` reading `GET /api/admin/security`; admin-only tile in More.
- **CSRF:** the app authenticates with a bearer JWT, never a cookie, so a foreign page cannot ride a session. The server still refuses cross-origin state changes and logs `CSRF_REJECTED`.
- **Scheduling the monitor:** `npm run monitor` (or `npx tsx scripts/monitor.ts`) every 15 minutes from Windows Task Scheduler; run by hand in the demo.
- **Hashing vs encryption:** hashes are one-way (passwords, answers, OTPs); AES-256-GCM is reversible and is used only for the Government ID.
- **Secrets outside the web root:** `.env` is never served and is git-ignored.

Long form with reasoning: `docs/design-decisions.md`.

## 8. Error message mapping (core + system)

The full table is `docs/error-message-mapping.md`. Key rows:

| Input | Field | Message |
|---|---|---|
| `juan` | First Name | First letter of your name must be capital. |
| `JUAN` | First Name | Do not use all capital letters. |
| `Ju4n` | First Name | Numbers are not allowed in First Name. |
| `Juan!` | First Name | Special characters are not allowed in First Name. |
| `Juan  Carlo` | First Name | Double space is not allowed. |
| `Juaaan` | First Name | Three consecutive identical letters are not allowed. |
| `1234-567` | ID Number | ID Number must follow the format xxxx-xxxx. |
| `juan@` | Email | Please enter a valid email address. |
| age 17 | Birthdate | You must be at least 18 years old to register. |
| unticked | Consent | You must agree to the Privacy Notice to register. |
| duplicate | ID Number | This ID Number is already registered. |
| duplicate | Email | This email is already registered. |
| duplicate | Username | That username is already taken. |
| weak | Password | Password must include an uppercase letter and a number. |
| mismatch | Re-enter Password | Passwords do not match. |
| reuse | Change Password | You cannot reuse a recent password. |
| wrong code | OTP | That code is invalid or expired. Request a new one. |

## 9. Test evidence

Automated, repeatable: `cd backend && npx tsx scripts/verify-handout.ts`

```
PASS  admin dashboard rejects anonymous — 401
PASS  normal user gets 403 on admin dashboard
PASS  ADMIN_ACCESS_DENIED written to activity log
PASS  admin dashboard returns summary + events — 50 events
PASS  admin session carries isAdmin=true
PASS  6-minute idle timeout returns 401 SESSION_IDLE
PASS  authenticated request refreshes last_activity_at
PASS  security headers X-Frame-Options + nosniff — DENY / nosniff
PASS  foreign Origin rejected as CSRF_REJECTED — 403
```

Manual evidence (12–16 Nov 2026):

- Server-side validation with no client help: lowercase name, all caps, digits,
  special characters, triple letters, bad ID, bad email, under-18 → exact messages above.
- Honeypot filled → `201` with no account and no OTP.
- Registration → real “verify your account” email → OTP activates the account.
- Login: password + reCAPTCHA → “log-in code” email → session only after the code.
- 3 wrong OTPs → the correct code is refused.
- 3 wrong passwords → `423`, `retryAfter: 16`; a new session is still locked.
- Forgot password: username + reCAPTCHA → Q6/Q1/Q3 → wrong answer refused →
  correct answer → reset code → single-use grant → new password → replay refused.
- Reset does not accept the previous password (`password_history`).
- Admin endpoint: 200 with summary/hourly/top IPs/flags/50 events for an admin,
  401 without a token, 403 + `ADMIN_ACCESS_DENIED` for a normal user.
- Admin dashboard screen loads, filters by event/username/IP/date and refreshes
  every 60 s without spamming `ADMIN_VIEWED_DASHBOARD`.
- IP blocking: 13 failures in 10 minutes writes `ip_blocks` and `IP_BLOCKED`;
  the ledger survives a restart because `ipBlockSeconds` reads the table.
- Idle guard warns at 5 minutes and signs out at 6 minutes.
- Unknown paths, including `.php` and `.ts` probes, answer 404 “Page not found.”
- Monitoring script prints the IT 107 report and writes `security_flags`.
- Database: passwords, answers and OTPs are hashes; Government ID is ciphertext.

## 10. Submission artefacts

| Deliverable | Location |
|---|---|
| Git repository | app repo |
| SQL dump | `backend/sql/tahanan_dump.sql` |
| Seed table | section 1 / `docs/seed-table.md` |
| Threat model | `docs/threat-model.md` |
| Design decisions | `docs/design-decisions.md` |
| Privacy note | `docs/privacy-note.md` |
| Error message mapping | `docs/error-message-mapping.md` |
| Development journal | `docs/development-journal.md` |
| Test accounts | `docs/test-accounts.md` |
| Item-by-item checklist | `docs/handout-checklist.md` |

## 11. Development journal

`docs/development-journal.md` — one entry per week, honest about what was
rebuilt after the handout was released.

## 12. Known process gaps (cannot be closed by code)

1. **Git history:** the repository is not initialised here (`Is directory a git
   repo: no`). 30 commits across four weeks must be created by the student.
2. **Signature:** the System Proposal needs the instructor's signature and date.
3. **Live demo:** the on-the-spot requirement and the 6+6+8 minute demo are
   performed by the student.
4. **Proposal approval:** first-come-first-served approval happened offline.
