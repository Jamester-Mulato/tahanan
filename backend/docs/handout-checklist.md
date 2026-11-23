# Handout checklist — item-by-item status

**Legend**
- **Done** — implemented in Tahanan and reachable in the running system.
- **Equivalent** — implemented in the app/API equivalent of the handout's page
  wording; the deviation is explained in `design-decisions.md`.
- **Student** — process step that only the student can perform (signature,
  live demo, Git history). The artefact or data is ready.
- **N/A** — the handout states no requirement.

Every row below corresponds to one checkbox in
`Security 1 Handout System Requirements Checklist.docx`.

## How to verify in two minutes

```powershell
# 1. API checks (admin access, idle timeout, CSRF, headers)
cd backend
npx tsx scripts/verify-handout.ts

# 2. Monitoring script
npx tsx scripts/monitor.ts

# 3. Demo accounts (idempotent)
npx tsx scripts/seed-test-accounts.ts

# 4. Flutter static analysis
cd ..
flutter analyze --no-pub
```

Then sign in as `tahananadmin` (see `docs/test-accounts.md`) and open
**More → Security monitoring** (or the button on the house-list screen).

## Pages 1–6

| Page | Requirement | Status | Where / why |
|---|---|---|---|
| 1 | Cover table: name, student no., D1/D2, system, approved by, date | Student | Values ready: Jamester C. Mulato, 241-00315, D1=1, D2=5, Tahanan |
| 2 | Working web system in PHP/JS/HTML/CSS/MySQL | Equivalent | Flutter web + Android, Express, PostgreSQL 18; documented deviation |
| 2 | Registration, verification, log-in, lockout, alerts, recovery, dashboard | Done | `lib/`, `backend/src` |
| 2 | Every flow step checked on the server | Done | All validation and state live in `backend/src` |
| 3 | Contents page | N/A | No requirement |
| 4 | Explain every feature at the demo | Student | — |
| 4 | Build an unseen requirement live | Student | — |
| 4 | Use own system/fields, limits from own student number | Done | `docs/seed-table.md` |
| 4 | Match the approved proposal and seed | Student | Proposal approval is offline |
| 4 | No one else's project | Student | — |
| 5 | System needs protected accounts and personal data | Done | Tenancy + government ID data |
| 5 | Nobody else has the same system | Student | Approval is first-come-first-served |
| 5 | Complete the System Proposal (Appendix A) | Student | Data available in `handout-compliance.md` §2 |
| 5 | 4+ system fields, 3+ kinds, rule + required + error | Done | Government ID, Move-in Date, Room Type, Emergency Contact, Tenancy Notes |
| 5 | Proposal signed at Checkpoint 1 | Student | — |
| 5 | Approved system name as prospect name | Done | “Tahanan” used throughout |
| 5 | Compute D2 and D1 | Done | D2=5, D1=1 |
| 5 | Seed table “Mine” column on first page | Done | `docs/seed-table.md` |
| 5 | Min username = 6 + (D1 mod 3) | Done | **7** |
| 6 | Max username = 16 + (D2 mod 5) | Done | **16** |
| 6 | Min password = 8 + (D2 mod 4) | Done | **9** |
| 6 | Max name length = 20 + D2 | Done | **25** |
| 6 | Failures before “Forgot Password?” = 2 + (D1 mod 2) | Done | **3** |
| 6 | Lockout tier 1 = 15 + D1 | Done | **16 s** |
| 6 | Lockout tier 2 = 30 + 2×D1 | Done | **32 s** |
| 6 | Lockout tier 3 = 60 + 4×D1 | Done | **64 s** |
| 6 | OTP expiry = 3 + (D2 mod 3) | Done | **5 min** |
| 6 | Idle timeout = 5 + (D1 mod 5) | Done | **6 min**, server + app |
| 6 | IP block threshold = 8 + D2 in 10 min | Done | **13 attempts / 10 min** |
| 6 | Question A = Q[(D2 mod 8)+1] | Done | **Q6** |
| 6 | Question B = Q[((D2+3) mod 8)+1] | Done | **Q1** |
| 6 | Question C = Q[((D2+5) mod 8)+1] | Done | **Q3** |

## Pages 7–12

| Page | Requirement | Status | Where / why |
|---|---|---|---|
| 7 | Approved name above the header on every page | Equivalent | Mobile app shell: brand on splash, sign-in and More; each screen has its own titled header. No page-level web header exists. |
| 7 | Header links in the upper-right | Equivalent | Nav pills (Log in / Sign up) and tab bar |
| 7 | Copyright in the footer | Equivalent | `© 2026 Jamester C. Mulato. All rights reserved.` on the sign-in, change-password and More screens (app equivalent of a global footer) |
| 7 | Home header: Home / Register / Log-in | Equivalent | Login screen switcher |
| 7 | Log-in header: Home / Register | Equivalent | Switcher + back |
| 7 | Register header: Home / Log-in | Equivalent | Back to sign in |
| 7 | After log-in: Home / Log-out | Equivalent | Tabs + More → Sign out |
| 7 | Never show Log-out to a visitor | Done | Sign out only inside the authenticated shell |
| 7 | Field name above the input | Done | `PremiumField`, date/dropdown fields |
| 7 | Required: red asterisk | Done | Red `*` |
| 7 | Optional: red “optional” | Done | Middle Name, Name Extension, Tenancy Notes |
| 7 | ID Number placeholder `xxxx-xxxx` | Done | Register screen |
| 7 | Error under its own field | Done | Per-field `error` |
| 8 | Validate every field in browser and server | Done | Client + `security/registration.ts` |
| 8 | Core fields complete | Done | ID, names, extension, birthdate/age, address, email, username, passwords, questions, consent |
| 8 | System fields from the proposal | Done | Six extra tenancy fields |
| 8 | Formatted number, encrypted, exact message | Done | Government ID `xxxx-xxxx-xxxx`, AES-256-GCM |
| 8 | Dropdown validated on the server | Done | Room Type, Name Extension |
| 9 | Privacy Notice page linked from registration | Done | `lib/widgets/privacy_notice.dart` |
| 9 | Required consent, unchecked, exact text | Done | Exact RA 10173 wording |
| 9 | Refuse without consent, store time | Done | `users.privacy_consent_at` |
| 9 | Collect only needed data | Done | `docs/privacy-note.md` justifies every field |
| 9 | ID Number format `xxxx-xxxx` | Done | Client + server |
| 9 | ID Number primary key | Equivalent | Unique identity column; UUID keys kept for FK integrity |
| 9 | Username and email unique | Done | Unique indexes + messages |
| 9 | Passwords hashed | Done | scrypt |
| 9 | Explain hashing choice | Done | `docs/design-decisions.md` §1 |
| 9 | Name rules 1–8 | Done | Letters, no specials, no digits, no double space, not all caps, no triple letters, Title Case, 2–25 |
| 10 | Middle Name optional but rules apply | Done | |
| 10 | Extension Jr./Sr./Other; I, II, III, IV, IX, X | Done | Server rejects anything else |
| 10 | Age auto, read-only | Done | Computed, displayed |
| 10 | Age recalculated on server | Done | `ageFromBirthdate` |
| 10 | Under 18 / future birthdate rejected | Done | Exact messages |
| 10 | Purok/Street rule | Done | 3–50, letters/digits/spaces |
| 10 | Barangay/City/Province/Country Title Case | Done | 2–50 |
| 10 | ZIP exactly 4 digits | Done | |
| 10 | Email format, ≤100, lowercase | Done | |
| 10 | Email unique message | Done | “This email is already registered.” |
| 10 | Real inbox for OTP/alerts | Done | Gmail account, plus-addressing |
| 10 | Username rules 7–16, starts with letter | Done | |
| 10 | Username availability while typing | Done | Debounced live check under the field |
| 10 | Password min 9, max 64 | Done | |
| 10 | Weak / Medium / Strong meter; weak blocked | Done | Registration + Change Password |
| 10 | Re-enter mismatch message | Done | “Passwords do not match.” |
| 10 | Weak/Medium/Strong rules documented | Done | `docs/design-decisions.md` §2 |
| 10 | Every error names the mistake | Done | `docs/error-message-mapping.md` |
| 11 | `juan` → capital message | Done | |
| 11 | `JUAN` → all caps message | Done | |
| 11 | `Ju4n` → numbers message | Done | |
| 11 | `Juan!` → specials message | Done | |
| 11 | `Juan  Carlo` → double space | Done | |
| 11 | `Juaaan` → triple letters | Done | |
| 11 | `1234-567` → ID format | Done | |
| 11 | `juan@` → valid email | Done | |
| 11 | Age 17 → 18+ message | Done | |
| 11 | Unticked consent message | Done | |
| 11 | Error Message Mapping table | Done | `docs/error-message-mapping.md` |
| 12 | Three seeded questions, all required | Done | Q6, Q1, Q3 |
| 12 | 8-question bank | Done | `security/questions.ts` |
| 12 | Answers 2–50 letters/spaces, no double space | Done | |
| 12 | Answers hashed, lowercased | Done | |
| 12 | Explain why answers are hashed | Done | `docs/design-decisions.md` §4 |

## Pages 13–19

| Page | Requirement | Status | Where / why |
|---|---|---|---|
| 13 | 6-digit OTP in register / login / reset | Done | `login-otp.service.ts` |
| 13 | Secure random generation | Done | `crypto.randomInt` |
| 13 | Hashed, purpose, expiry, attempts | Done | `login_otps` |
| 13 | Seeded expiry + stated in email | Done | 5 minutes |
| 13 | Three wrong entries cancel the code | Done | `OTP_MAX_ATTEMPTS = 3` |
| 13 | Single use; new code cancels old | Done | `used` flag |
| 13 | Resend: 60 s cooldown, max 3 / 15 min | Done | Server window + visible countdown |
| 13 | Cannot skip the OTP step by URL | Done | No token issued before verification |
| 13 | OTP email purpose, code, expiry | Done | Login / verify / reset variants |
| 13 | Exact “If you did not request…” line | Done | All three templates |
| 13 | OTP email has no password or login link | Done | |
| 13 | PHPMailer over SMTP | Equivalent | Nodemailer over Gmail SMTP (App Password) |
| 13 | SMTP password never in Git | Done | `backend/.env` git-ignored |
| 14 | CAPTCHA on registration, log-in, forgot | Done | reCAPTCHA v2, math fallback |
| 14 | Server verifies reCAPTCHA secret | Done | `recaptcha.service.ts` |
| 14 | Image CAPTCHA alternative | N/A | reCAPTCHA chosen; math CAPTCHA is the fallback |
| 14 | Refuse if CAPTCHA is removed | Done | Server requires it |
| 14 | Failed-CAPTCHA decision documented | Done | Design decisions §3 |
| 15 | Step 1 username/password/CAPTCHA | Done | |
| 15 | Step 2 send OTP, no session | Done | |
| 15 | Step 3 session only after OTP | Done | |
| 15 | Identical “Invalid username or password.” | Done | |
| 15 | Show Password toggle | Done | |
| 15 | Forgot link after 3 failures | Done | “Forgot Password? Reset Here” |
| 15 | Lockout 16 / 32 / 64 s | Done | |
| 15 | Countdown; login and register disabled | Done | |
| 15 | Failure counter reset on success | Done | |
| 15 | Lockout enforced on the server | Done | |
| 15 | Every protected page checks the session | Done | `requireAuth` |
| 15 | Back after logout cannot show protected data | Done | Server-authorised data only |
| 15 | Idle warning 1 min before, then logout | Done | `IdleSessionGuard` |
| 15 | Explain why the back button is not enough | Done | Design decisions §6 |
| 16 | Tier-1 alert e-mail | Done | Subject “Failed sign-in attempts on your account” |
| 16 | Once per tier | Done | Sent only on tier boundaries |
| 16 | Password-changed e-mail | Done | Subject “Your password was changed” |
| 16 | No e-mail for unknown username | Done | |
| 16 | Alert: attempts, PHT time, IP, device | Done | |
| 16 | “Reset your password now” link | Done | Link to the app's forgot flow |
| 16 | Alert never contains a password | Done | |
| 16 | Login page does not reveal the alert | Done | |
| 16 | ALERT_EMAIL_SENT logged | Done | |
| 17 | Forgot step 1: username + CAPTCHA | Done | |
| 17 | Forgot step 2: the user's three questions | Done | |
| 17 | Forgot step 3: hashed answer, lockout counted | Done | |
| 17 | Forgot step 4: reset OTP | Done | |
| 17 | Forgot step 5: change password only after OTP | Done | Single-use reset grant |
| 17 | Unknown username behaves identically | Done | |
| 17 | Remember the five steps; documented | Done | Design decisions §5 |
| 17 | Change Password fields + meter | Done | |
| 17 | Same length rules; weak refused | Done | |
| 17 | Last 3 passwords refused | Done | Exact message |
| 17 | “Successfully Change Password” / “Mismatch Password” | Done | |
| 17 | New password hashed | Done | scrypt |
| 17 | Reset is used up | Done | `used` flag |
| 17 | Password-changed e-mail | Done | |
| 18 | No real secret in Git | Done | `.env` ignored; `.env.example` has fakes |
| 18 | P1 prepared statements | Done | Every query uses `$1…` |
| 18 | P2 escape output incl. logs | Equivalent | Flutter text rendering has no HTML sink |
| 18 | P3 CSRF token on POST | Equivalent | Bearer JWT + server origin guard + `CSRF_REJECTED` |
| 18 | P4 identical enumeration messages | Done | |
| 18 | P5 IP block 13 / 10 min across accounts | Done | Persisted in `ip_blocks` |
| 18 | P6 session hardening | Equivalent | JWT, token version, idle 6 min, logout revokes |
| 18 | P7 last 3 password hashes | Done | |
| 18 | P8 honeypot | Done | Hidden `website` field |
| 18 | P9 activity log with time/IP/browser | Done | |
| 18 | P10 no PHP/SQL errors; log file outside web root | Done | `backend/logs/error.log` |
| 18 | P11 secrets in config outside web root | Done | `backend/.env` |
| 18 | P12 X-Frame-Options + nosniff | Done | Helmet, verified |
| 19 | P13 AES-256 encryption of a sensitive field | Done | AES-256-GCM + random IV |
| 19 | Hashing vs encryption explained | Done | Design decisions §12 |

## Pages 20–26

| Page | Requirement | Status | Where / why |
|---|---|---|---|
| 20 | Read-only admin-only activity page | Done | Flutter security dashboard |
| 20 | Admin created directly in the database | Done | `tahananadmin` seeded by script |
| 20 | Admin logs in with OTP | Done | Same flow |
| 20 | Normal user gets “Access denied” + log | Done | 403 + `ADMIN_ACCESS_DENIED` |
| 20 | Log ADMIN_VIEWED_DASHBOARD on open | Done | Once per open, not per refresh |
| 20 | All 13.2 elements present | Done | |
| 20 | Summary cards (7 metrics) | Done | |
| 20 | Failed log-ins per hour, 24 h | Done | Custom bar chart |
| 20 | Top 5 IPs + blocked status | Done | |
| 20 | Flags from the monitor | Done | |
| 21 | Latest 50 events with filters | Done | Date range, event, username, IP |
| 21 | No edit/delete/clear buttons | Done | |
| 21 | Never UPDATE/DELETE log rows | Done | Trigger rejects both |
| 21 | 60-second refresh via admin-checked JSON | Done | |
| 21 | Escape displayed log values | Equivalent | Flutter text widgets |
| 21 | Decide whether the DB role may delete logs | Done | Design decisions §7 |
| 21 | Log REGISTERED | Done | |
| 21 | Log ACCOUNT_VERIFIED | Done | |
| 21 | Log LOGIN_SUCCESS | Done | |
| 21 | Log LOGIN_FAILED with typed username | Done | `username_typed` |
| 21 | Log OTP_SENT / OTP_FAILED | Done | |
| 21 | Log LOCKOUT_TIER_1/2/3 | Done | |
| 21 | Log IP_BLOCKED | Done | Logged at threshold |
| 21 | Log ALERT_EMAIL_SENT | Done | |
| 21 | Log RESET_REQUESTED / PASSWORD_CHANGED | Done | |
| 21 | Log CAPTCHA_FAILED / CSRF_REJECTED | Done | |
| 21 | Log ADMIN_VIEWED_DASHBOARD / ADMIN_ACCESS_DENIED | Done | |
| 21 | Log columns incl. username_typed | Done | `auth_events` |
| 22 | CLI monitor script | Done | `scripts/monitor.ts` (`npx tsx`) |
| 22 | Reads last 24 h | Done | |
| 22 | Pattern 1: IP over threshold | Done | Uses the seeded threshold |
| 22 | Pattern 2: username from 3+ IPs | Done | |
| 22 | Pattern 3: 5 OTP failures / 10 min | Done | |
| 22 | Pattern 4: off-hours LOGIN_SUCCESS | Done | PHT 00:00–05:00 |
| 22 | `security_flags` with daily dedupe | Done | Unique constraint |
| 22 | Console summary report | Done | Title, date/PHT, scanned, lines, counts |
| 22 | Unreachable from the browser | Done | CLI only; server 404s |
| 22 | Prepared statements in the script | Done | |
| 22 | Scheduling explained; run by hand | Done | Design decisions §11 |
| 23 | `css/` all styles | Equivalent | Flutter theme tokens |
| 23 | `js/` all scripts | Equivalent | Dart/Flutter; chart drawn natively |
| 23 | `php/` all server code | Equivalent | `backend/src` (TypeScript) |
| 23 | `images/` all images | Done | `assets/` |
| 23 | Monitor outside web root / blocked | Done | `backend/scripts` |
| 23 | Config outside web root, never committed | Done | `backend/.env` |
| 23 | `config.sample` with fake values, committed | Done | `backend/.env.example` |
| 23 | `.gitignore`: config, vendor, error log | Done | `backend/.gitignore` |
| 23 | HTML loads CSS/JS via tags | Equivalent | Flutter `index.html` loads the bundle |
| 23 | Directory listing off | Done | No directory static serving |
| 23 | Direct `.php`/`.js` shows “Page Not Found” | Done | 404 JSON “Page not found.” |
| 23 | Explain what hiding JS protects | Done | Design decisions §14 |
| 24 | Checkpoints 1–4 | Student | Work is complete; presentation is in person |
| 24 | Live demo | Student | — |
| 24 | 30 commits over 4 weeks | Student | Repository not initialised in this folder |
| 24 | SQL dump, all tables, 5+ test records | Done | `backend/sql/tahanan_dump.sql` |
| 24 | Signed System Proposal | Student | — |
| 24 | Seed table on the first page | Done | `docs/seed-table.md` |
| 24 | Threat Model (Appendix B) | Done | `docs/threat-model.md` |
| 24 | Design Decisions | Done | `docs/design-decisions.md` |
| 24 | Privacy note | Done | `docs/privacy-note.md` |
| 24 | Error Message Mapping | Done | `docs/error-message-mapping.md` |
| 24 | Development Journal | Done | `docs/development-journal.md` |
| 24 | Test accounts: 1 admin + 2 users | Done | `docs/test-accounts.md` |
| 25 | Run in person on an online laptop | Student | — |
| 25 | Part 1 demo script (6 min) | Student | — |
| 25 | Part 2 explain four code parts | Student | — |
| 25 | Part 3 build a new requirement live | Student | — |
| 25 | Explain every feature | Student | — |
| 26 | DB shows no readable secret | Done | Verified |
| 26 | JS off: server catches bad input | Done | API tests |
| 26 | Reload/cookies/button cannot bypass lockout | Done | Server lock |
| 26 | Alert e-mail has time, IP, browser | Done | |
| 26 | Typing the user URL at the OTP step fails | Done | No session yet |
| 26 | Typing the Change Password URL fails | Done | Reset grant required |
| 26 | 3 wrong OTPs → correct one fails | Done | |
| 26 | Old code after expiry fails | Done | |
| 26 | `' OR '1'='1` gives no SQL error/login | Done | |
| 26 | `<script>alert(1)</script>` shows no alert | Done | |
| 26 | Deleting CSRF/CAPTCHA is rejected | Done | |
| 26 | Wrong username/password messages identical | Done | |
| 26 | Changing to the current password is rejected | Done | |
| 26 | Idle past timeout logs out | Done | Server + app |
| 26 | Normal user cannot open the dashboard | Done | 403 |
| 26 | Dashboard JSON empty when logged out | Done | 401 |
| 26 | Monitor script does not run from the browser | Done | 404 |
| 26 | No path edits/deletes a log row | Done | Trigger + no route |
| 26 | Git history has no secrets | Student | No Git repository yet |
| 26 | Lockout countdown matches the seed | Done | 16 s / 32 s / 64 s |

## Pages 27–32 (rubric + appendices)

| Page | Requirement | Status | Where / why |
|---|---|---|---|
| 27 | F1 registration validation + messages | Done | |
| 27 | F2 Privacy Notice + consent | Done | |
| 27 | F3 OTP in all three flows, all rules | Done | |
| 27 | F4 lockout countdown, forgot link, disabled buttons | Done | |
| 27 | F5 forgot + change password end to end | Done | |
| 27 | F6 CAPTCHA on all three forms | Done | |
| 27 | F7 alert e-mails at the right moments | Done | |
| 27 | F8 dashboard shows every element | Done | |
| 27 | F9 monitor detects four patterns | Done | |
| 27 | Explain every feature | Student | |
| 27 | Score split | N/A | Information only |
| 28 | S1 hashed secrets | Done | scrypt |
| 28 | S2 AES-256 field | Done | |
| 28 | S3 server validation with JS off | Done | |
| 28 | S4 lockout + IP blocking on server | Done | |
| 28 | S5 OTP/change-password/dashboard unreachable | Done | |
| 28 | S6 SQL injection and XSS fail | Done | |
| 28 | S7 CSRF + CAPTCHA server verified | Done | |
| 28 | S8 session hardening + idle | Done | |
| 28 | S9 no username enumeration | Done | |
| 28 | S10 no secrets, hidden errors, headers | Done | |
| 28 | S11 append-only logs, read-only dashboard | Done | |
| 28 | D1 run every flow live | Student | |
| 28 | D2 explain four code sections | Student | |
| 28 | A1 build the new requirement | Student | |
| 28 | A2 explain the change | Student | |
| 28 | G1 prospect name, header/footer, log-in state | Equivalent | App shell navigation |
| 28 | G2 labels above, asterisk/optional, placeholder, errors, countdowns | Done | |
| 29 | G3 visual quality and responsive layout | Done | |
| 29 | P1 30 commits / 4 weeks | Student | |
| 29 | P2 Development Journal | Done | |
| 29 | P3 Threat Model with CIA | Done | |
| 29 | P4 Design Decisions | Done | |
| 29 | P5 Privacy note | Done | |
| 29 | P6 Error Message Mapping | Done | |
| 29 | CO1–CO5 | N/A | Covered by the rubric |
| 30 | Complete Appendix A | Student | Content ready |
| 30 | Name, users, data, why protect | Done | |
| 30 | Sensitive field to encrypt | Done | Government ID |
| 30 | System fields table, 4+ fields, 3+ kinds | Done | |
| 30 | Instructor decision, signature, date | Student | |
| 31 | Threat model, one row per protection (13) | Done | `docs/threat-model.md` |
| 31 | Columns: threat, vulnerability, countermeasure, CIA, tested | Done | |
| 32 | Journal, one page per week | Done | `docs/development-journal.md` |
| 32 | Weekly fields incl. commits | Done | Commit count reported honestly as 0 (repo not initialised) |
