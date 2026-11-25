# Tahanan — Live Demo Flow

**System:** Tahanan — Boarding House Tenant & Rent System
**Student:** Jamester C. Mulato (241-00315) · D1 = 1 · D2 = 5
**Seed:** username 7–16 · password min 9 · names max 25 · forgot link at 3 · lockout 16/32/64 s · OTP 5 min · idle 6 min · IP 13/10 min · Q6, Q1, Q3

This is the order to run the demo in. Each block names what to click, what the screen must show, and the exact sentence to say. The **Proves** tag maps the step to the handout item it satisfies.

---

## 0. Pre-flight (do this before the examiner sits down)

- [ ] Start PostgreSQL, then the API: `cd backend` and `npm run dev`
- [ ] Start the app: `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080`
- [ ] Open `jamestermulato@gmail.com` in a second window and leave it on the inbox
- [ ] In a terminal at `backend/`, run: `npx tsx scripts/seed-test-accounts.ts`
- [ ] Keep a second terminal at `backend/` for the attack pack and the monitor
- [ ] Close every other tab, chat window and notes app
- [ ] Have this sheet on paper, not on screen

**Tabs/windows to have open:** the app, the Gmail inbox, terminal A (API), terminal B (scripts).

**Timing:** Part 1 ≈ 6 min · Part 2 ≈ 6 min · Part 3 ≈ 8 min. The extra flows below can be shown before or after the judged 20 minutes.

---

## 1. Tenant registration — the whole form on the server

**Proves:** F1, F2, S1, S3, P8, P13; handout 4.1–4.11, 12.

### 1.1 Show the layout first (30 s)

Open **Sign up**. Walk the four steps without typing:

| Step | Title | What to point at |
|---|---|---|
| 1 | Tell us who you are | ID Number placeholder `xxxx-xxxx`, birthdate, computed age |
| 2 | Where do you live? | six address fields, all required |
| 3 | Your tenancy details | Government ID, move-in date, room type, emergency contact, notes |
| 4 | Secure your account | username, password meter, three seeded questions, consent |

**Say:** “Every label sits above its field, required fields carry a red asterisk, optional fields say optional, and every message appears under the field that caused it.”

### 1.2 Break the form on purpose (3 min)

Type each value, press **Continue**, and read the message that appears *under that field*:

| Field | Value to type | Exact message you must see |
|---|---|---|
| First Name | `juan` | First letter of your name must be capital. |
| First Name | `JUAN` | Do not use all capital letters. |
| First Name | `Ju4n` | Numbers are not allowed in First Name. |
| First Name | `Juan!` | Special characters are not allowed in First Name. |
| First Name | `Juan  Carlo` | Double space is not allowed. |
| First Name | `Juaaan` | Three consecutive identical letters are not allowed. |
| ID Number | `1234-567` | ID Number must follow the format xxxx-xxxx. |
| Birthdate | a date making the tenant 17 | You must be at least 18 years old to register. |
| ZIP Code | `123` | ZIP Code must be exactly 4 digits. |
| Email | `juan@` | Please enter a valid email address. |
| Username | `1juan` | Username must start with a letter and use letters and digits only. |
| Password | `password` | Password must include an uppercase letter and a number. (meter shows **Weak**) |
| Re-enter Password | a different value | Passwords do not match. |
| Government ID | `1234-5678` | Government ID Number must follow the format xxxx-xxxx-xxxx. |
| Move-in Date | tomorrow | Move-in Date must be a valid date between 2000-01-01 and today. |
| Emergency Contact | `12345` | Contact number must be 11 digits and start with 09. |
| Tenancy Notes | `needs  a/c!` | Tenancy Notes may contain letters, digits, commas, periods and spaces only, up to 200 characters. |
| Any answer | `Bantay 2` | Answer A may contain letters and spaces only. |
| Privacy consent | leave unticked | You must agree to the Privacy Notice to register. |

**Say:** “Every one of these is also enforced by the API. The browser is a convenience; the server is the authority.” **Proves S3.**

### 1.3 Prove the server is the authority (1 min)

With the app still open, run this in terminal B:

```powershell
try {
  Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8080/api/auth/register `
    -ContentType 'application/json' `
    -Body '{"id_number":"1234-567","first_name":"juan","email":"juan@"}'
} catch {
  $_.ErrorDetails.Message
}
```

The response is `422` with `details.id_number`, `details.first_name` and `details.email` carrying the same messages. **Proves S3.**

> Use `Invoke-RestMethod` here, not `curl.exe -d "{...}"`. Windows PowerShell strips the inner quotes when JSON is handed to a native program, so curl receives `{id_number:...}` and the server correctly answers `400 INVALID_JSON`.

### 1.4 Register correctly (2 min)

Fill the form properly:

- ID `2026-0002`, First `Maria`, Middle optional, Family `Santos`, Birthdate 1998
- Address: `Purok 3`, `Barangay 1`, `Cabadbaran City`, `Agusan del Norte`, `Philippines`, `8600`
- Government ID `1111-2222-3333`, move-in today, Room Type `Single`, emergency `09171234567`
- Email a plus-address you own, username `mariasantos`, password `Maria#2026`
- Answers: `Bahay Kubo`, `Bantay`, `Mrs Cruz`
- Read the **Privacy Notice** link, then tick the consent box

**Say:** “The consent box starts unticked, uses the exact RA 10173 wording, and the server stores the timestamp in `users.privacy_consent_at`.” **Proves F2.**

**Say:** “The Government ID is encrypted with AES-256-GCM before it is stored.” **Proves P13 / S2.**

### 1.5 The invisible trap (30 s)

The honeypot field is not rendered, so there is nothing to show. Prove it from the terminal:

```powershell
$r = Invoke-WebRequest -Method Post -Uri http://127.0.0.1:8080/api/auth/register `
  -ContentType 'application/json' `
  -Body '{"website":"http://bot.example","id_number":"9999-9999"}' -UseBasicParsing
"$($r.StatusCode) $($r.Content)"
```

It answers `201` and creates no account. **Say:** “A bot that fills every field it can see trips this and gets a fake success; a person never sees the field.” **Proves P8.**

---

## 2. Email verification and OTP

**Proves:** F3, P11; handout section 6.

1. Open the inbox. Show the **“Verify your account”** email.
2. Point at: the 6-digit code, the **5-minute** expiry, and the line **“If you did not request this code, ignore this email and consider changing your password.”**
3. Point out that the email contains no password and no link that logs you in.
4. Enter a **wrong** code three times. The screen must say **“That code is invalid or expired. Request a new one.”** and then **“Three wrong entries cancelled this code. Request a new one to continue.”**
5. Enter the **correct** code. It must now fail: the code was cancelled.
6. Tap **Resend code**. Show the **60-second** countdown and that the button is disabled until it reaches zero.
7. Enter the new code. The account activates and the session is created only now.

**Say:** “Codes are generated with `crypto.randomInt`, stored as a scrypt hash, single-use, cancelled by a new request, and expired after five minutes. Three wrong entries kill the code even if the next entry is right.”

---

## 3. Log-in, lockout and alert emails

**Proves:** F4, F7, S4, S8, S9, P5, P10; handout sections 8–9.

### 3.1 The correct flow

1. Sign out, then **Log in** with the tenant account.
2. Point at the **Show password** toggle.
3. Submit username, password and CAPTCHA.
4. The app goes to the **OTP** screen. **Say:** “No session exists yet; the server has only checked the password.”
5. Open a protected address (the dashboard or `/api/me`) in another tab. It must be refused.
6. Enter the emailed log-in code. The session starts here.

### 3.2 Identical errors (30 s)

1. Log out. Try a username that does not exist, with any password.
2. Try the real username with a wrong password.

Both must say exactly **“Invalid username or password.”** with the same status. **Say:** “The response time is levelled with a dummy scrypt verify, so timing does not leak which half was wrong.” **Proves P4 / S9.**

### 3.3 Lockout (2 min)

1. Fail the password three times on the real account.
2. The countdown appears: **16 s**, the **Log in** button and the **Sign up** link are both disabled, and **“Forgot Password? Reset Here”** appears.
3. Reload the page. Clear cookies. Try to re-enable the button in DevTools. Nothing gets in.
4. Prove it on the server while the countdown runs. In terminal B:

```powershell
npx tsx scripts/demo-lockout.ts
```

Expected output ends with `423 — Too many attempts. Try again in 16 seconds. (retryAfter 16)` and prints `failed_login_count: 3` with a `locked_until` timestamp. **Say:** “The lock lives in `users.locked_until`, so the client cannot talk its way past it.” **Proves S4.**

5. After the first lock expires, keep failing: the sixth failure must be **32 s** and the ninth **64 s**. The failure streak survives the lock; only a successful sign-in resets it.

### 3.4 The alert email (1 min)

At the first tier, open the inbox. The subject is **“Failed sign-in attempts on your account”**. Show:

- the number of attempts
- the date and time in Philippine time
- the IP address
- the browser/device
- the **“reset your password now”** link

**Say:** “One email per tier, never one per attempt. An unknown username sends nothing. The log-in screen never says an alert was sent. Every send is written as `ALERT_EMAIL_SENT`.” **Proves F7 / P9.**

### 3.5 Idle timeout (optional, pre-staged)

Start this early and come back to it: leave a signed-in tab alone for six minutes. One minute before the deadline the app warns; at six minutes it signs out and the next request returns `401 SESSION_IDLE`.

If you cannot wait, the automated proof is in section 8:

```powershell
npx tsx scripts/verify-handout.ts
```

**Proves S8 / P6.**

---

## 4. Forgot password and Change Password

**Proves:** F5, P7, S1, S5; handout sections 10–11.

1. **Forgot Password** → username + CAPTCHA.
2. Try a username that does not exist. It shows the **same three questions**, so the page does not reveal whether the account exists. **Proves P4.**
3. Answer and re-answer differently → **“Answers do not match.”**
4. Answer wrongly → **“One of those details is incorrect.”** and the failure counts toward the same lockout as log-in.
5. Answer correctly → the **reset code** email arrives (5-minute expiry, same wording rules).
6. Enter three wrong codes → the code is cancelled; request a new one.
7. Enter the correct code → the app opens **Change Password**.
8. Try to open Change Password directly without completing the steps. It does not open; the API answers **“This reset has expired. Start the forgotten-password steps again.”** **Say:** “A single-use reset grant is issued only after the OTP.” **Proves S5.**
9. New password tests:
   - `password` → weak, refused, meter shows **Weak**
   - two different values → **“Mismatch Password”**
   - the current password → **“You cannot reuse a recent password.”**
10. Set a new valid password → **“Successfully Change Password”**.
11. The inbox gets **“Your password was changed”**, and the log has `PASSWORD_CHANGED` + `ALERT_EMAIL_SENT`.
12. Reload the reset screen: the grant is used up and cannot be replayed.

**Say:** “Passwords, answers and codes are one-way scrypt hashes; the reset grant is a hashed, expiring, single-use token.” **Proves S1 / P7.**

---

## 5. Owner journey

**Proves:** G1–G3; the business flow behind the accounts.

1. Sign out, then log in as the owner (`devicetest` / `AppTest2026`) with OTP.
2. **Houses → Create house**: name it, pick a layout preset, set rooms and beds. Finish and show the **join key** (format `GHBV-8X7K-2P9M`).
3. Open the house → **Add room** (number + beds).
4. **Add tenant** and associate the tenant account from section 1.
5. Set this month’s **rent status** for that tenant (paid / unpaid).
6. **Post notice** — for example, “Water interruption on Saturday”.
7. **Concerns** — leave this open; the tenant replies in section 6.

**Say:** “Owners and tenants use the same authentication. The role is a membership of a boarding house, checked on the server for every house-scoped call.”

---

## 6. Tenant journey, continued

1. Sign in as the tenant (`hand2372` / `Handout#2027`) with OTP.
2. If the house is not listed, **Join with key** and paste the owner’s key.
3. Show the tenant home: room, **Payments** (the status the owner just set), **Notices** (the announcement), and **Report**.
4. **Report** a concern: “The faucet in room 2 leaks.”
5. Switch back to the owner and show the concern arrives with the tenant’s name and room.

**Say:** “This is why the account matters: the tenant sees only their own room, rent and reports; the owner sees the house. That split is enforced by the API, not by hiding buttons.”

---

## 7. The attack pack (one command, eight checks)

**Proves:** P1, P2, P3, P4, P5, P8, P9, P12, S6, S7, S11.

Run in terminal B:

```powershell
cd backend
npx tsx scripts/demo-attacks.ts
```

Expected output:

```text
PASS  P1 SQL injection — status 401, message "Invalid username or password."
PASS  P2 XSS payload — status 401, stored 1 log row(s) verbatim
PASS  P4 username enumeration — unknown 401 vs known 401, same message: true
PASS  P3 CSRF (foreign Origin) — status 403, error CSRF_REJECTED
PASS  P8 honeypot — status 201, accounts created: 0
PASS  P5 IP blocking — blocked on attempt 14 (threshold 13/10 min)
PASS  P12 security headers — X-Frame-Options: DENY, X-Content-Type-Options: nosniff
PASS  P9 append-only log — 2/2 UPDATE or DELETE statements rejected by the trigger
```

Say one line per check:

- **P1** — `' OR '1'='1` is ordinary text to a prepared statement.
- **P2** — the payload is stored exactly as typed; Flutter renders it as text, so no script runs. You will see it on the dashboard in section 9.
- **P3** — a browser form from another site cannot ride the session; a foreign `Origin` is refused and logged.
- **P4** — unknown user and wrong password are indistinguishable.
- **P5** — thirteen failures in ten minutes from one IP blocks that IP; the block is persisted in `ip_blocks`.
- **P8** — a filled honeypot gets a fake success and creates nothing.
- **P12** — every response carries `X-Frame-Options: DENY` and `X-Content-Type-Options: nosniff`.
- **P9** — `UPDATE` and `DELETE` on the log are rejected by the database trigger, not just hidden in the UI.

> The attack pack sends `X-Forwarded-For: 203.0.113.77`, a reserved documentation address, so the real demo machine is not blocked.

---

## 8. Admin dashboard and the monitoring script

**Proves:** F8, F9, S10, S11; handout sections 13–14.

1. Sign out, then log in as the admin (`tahananadmin` / `Admin#24100315`) with OTP — the admin uses the same log-in with OTP, but is created directly in the database.
2. Open **More → Security monitoring** (admin-only tile).
3. Show, in order:
   - the seven summary cards: log-ins today, failed today, locked now, IPs blocked now, OTPs sent, OTP failed, alerts sent
   - the **failed log-ins per hour** chart for the last 24 hours
   - the **top five IP addresses** and whether each is blocked
   - the **monitoring flags** written by the script
   - the latest **50 events** with the date, event, username and IP filters
4. Point at what is *missing*: no edit, no delete, no clear-log button.
5. Point at the `<script>alert(1)</script>` username from the attack pack. It appears as text. No alert. **Proves P2 / S6.**
6. Leave the dashboard open and note the refresh: every 60 seconds, through a JSON endpoint that checks the admin session, and the refresh itself is not logged as a new view.
7. Sign in as a normal user and open the same dashboard. It says **“Access denied”** and writes `ADMIN_ACCESS_DENIED`.
8. With the dashboard signed out, call the JSON endpoint:

```powershell
curl.exe -s -i http://127.0.0.1:8080/api/admin/security
```

It answers `401` and no data. **Proves S5.**

9. Run the monitor:

```powershell
npx tsx scripts/monitor.ts
```

The report must show the date in PHT, the number of events scanned, one line per finding with `[HIGH]` or `[MED ]`, the target and counts, and **“New flags written”** / **“Already flagged today”**. Run it twice: the second run writes nothing new. **Proves F9.**

10. Try to open the script from the browser:

```powershell
curl.exe -s -i http://127.0.0.1:8080/scripts/monitor.ts
```

It answers **404 “Page not found.”** **Proves P10 / section 15.**

---

## 9. Close the demo (1 min)

Say these four sentences and stop:

1. “Passwords, answers and codes are one-way hashes; only the Government ID is encrypted, because only it has to be read back.”
2. “Every rule that protects data is enforced on the server, so modifying the app changes nothing.”
3. “The log is append-only at the database level, and the dashboard has no write path.”
4. “All limits come from my seed: 7–16 username, 9 password, 16/32/64 lockout, 5-minute OTP, 6-minute idle, 13 failures per IP, Q6/Q1/Q3.”

---

## 10. Recovery — if something breaks mid-demo

Run the SQL below in pgAdmin's Query Tool (or `psql`). Run the `npx tsx` commands in terminal B.

**Accounts missing or passwords changed**

```powershell
cd backend
npx tsx scripts/seed-test-accounts.ts
```

**An account is locked and you need it now**

```sql
UPDATE users SET failed_login_count = 0, locked_until = NULL;
```

**The demo IP is blocked**

```sql
DELETE FROM ip_blocks;
```

**Restart the whole demo data set**

```powershell
npx tsx scripts/seed-test-accounts.ts
npx tsx scripts/seed-demo-evidence.ts
npx tsx scripts/monitor.ts
```

**OTP email does not arrive**

- Check terminal A for a mail error.
- Confirm `backend/.env` still has `SMTP_USER` / `SMTP_PASS` (Gmail App Password).
- Check spam, and confirm the plus-address is exactly the one on the account.
- Fall back to the other demo account; the flow is identical.

**API not running**

```powershell
cd backend
npm run dev
```

---

## 11. Coverage map

| Handout item | Where it is shown |
|---|---|
| F1 registration + exact messages | 1.2–1.4 |
| F2 privacy notice + consent | 1.4 |
| F3 OTP in all three flows | 2, 3.1, 4 |
| F4 lockout + countdown + forgot link | 3.3 |
| F5 forgot + change password | 4 |
| F6 CAPTCHA on three forms | 1.4, 3.1, 4.1 |
| F7 alert emails | 3.4, 4.11 |
| F8 dashboard elements | 8.3–8.6 |
| F9 monitoring script | 8.9 |
| S1 hashing | 4.9–4.12 |
| S2 encryption | 1.4 |
| S3 server-side validation | 1.3 |
| S4 lockout + IP block on server | 3.3, 7 (P5) |
| S5 OTP/dashboard/reset unreachable | 3.1, 4.8, 8.8 |
| S6 SQLi + XSS | 7 (P1, P2), 8.5 |
| S7 CSRF + CAPTCHA | 7 (P3), 1.4 |
| S8 session + idle | 3.5 |
| S9 no enumeration | 3.2, 4.2 |
| S10 secrets, errors, headers | 7 (P12), 8.10 |
| S11 append-only + read-only | 7 (P9), 8.4 |
| P1–P13 | 1.5, 3, 4, 7 |
| G1–G3 layout and polish | throughout; 1.1, 5, 6 |
| Owner flow | 5 |
| Tenant flow | 6 |

---

## 12. Part 2 — the four code sections to be ready to explain

Open these before the demo and read them once. The examiner picks; these are the ones that carry the marks.

1. **`backend/src/security/registration.ts`** — the order of the name rules, `ageFromBirthdate`, the seeded lengths, and why the server repeats every client check.
2. **`backend/src/services/auth.service.ts`** — `authenticatePassword` (dummy hash, identical error), `registerFailedAttempt` (tiers 3/6/9, one alert per tier), and why the streak survives the lock.
3. **`backend/src/services/login-otp.service.ts`** — `randomInt`, the scrypt hash of the code, `attempts`, `expires_at`, the 60-second cooldown and the 3-per-15-minute window.
4. **`backend/src/security/crypto.ts`** — AES-256-GCM with a random IV, the auth tag, and the HMAC lookup that keeps uniqueness on encrypted data.

Backups if the examiner picks elsewhere: `throttle.service.ts` (per-IP window), `middleware/csrf.ts` (origin guard), `routes/admin.routes.ts` (authorisation + summary queries).

---

## 13. Part 3 — the unseen requirement

Keep it small and end to end. The safe pattern:

1. Add the rule on the server first.
2. Mirror the message in the Flutter screen.
3. Add the log event if the handout says the action must be logged.
4. Prove it with the app and with one `curl.exe` call.

Good candidates: a new name rule with its exact message, a new dashboard card, a new `auth_events` type, or an extra tenancy field with its format rule and message.
