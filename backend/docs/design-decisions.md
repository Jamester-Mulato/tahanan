# Design decisions — every “Your call”

**1. Hashing algorithm and settings.**
Passwords use scrypt with N=16384, r=8, p=1 and a 16-byte random salt, stored
as `scrypt$N$r$p$salt$hash`. scrypt is memory-hard, so GPU cracking is far more
expensive than with a plain SHA family hash, and Node ships it, so there is no
native build step on Windows or Android. Security answers and OTP codes use the
same function: both are low-entropy secrets that must not be readable if the
database leaks.

**2. Weak / Medium / Strong password rules.**
Weak = shorter than 9 characters, or missing an uppercase letter, or missing a
digit. Weak is refused by both the app and the server. Medium = meets those
three rules. Strong = Medium plus at least 12 characters and a symbol. The
minimum comes from the seed (8 + D2 mod 4 = 9); the extra tiers only encourage
better passwords without blocking a legal one.

**3. Does a failed CAPTCHA count as a failed log-in?**
No. CAPTCHA failures are logged as `CAPTCHA_FAILED` but do not increment the
account lockout, because an attacker who knows a username could otherwise lock
the real owner out by failing CAPTCHAs on purpose. Lockout is driven only by
wrong passwords and wrong security answers.

**4. Why security answers are hashed, not stored as text.**
Answers are short and guessable. If they were plain text, one SQL leak would
hand an attacker the exact values needed to reset every password. Hashing makes
the stored value useless, and lowercasing before hashing gives the required
case-insensitive match (“Bantay” matches “bantay”).

**5. How the server remembers that forgot-password steps 1–5 were completed.**
The reset screen needs a **reset grant**: a 24-byte random token whose SHA-256
hash is stored in `password_reset_tokens` with a short expiry and a `used`
flag. It is issued only after the reset OTP is accepted, is single-use, and is
checked again when the new password is submitted. Opening the Change Password
screen without a grant does nothing.

**6. Why disabling the back button is not enough.**
The back button is a browser affordance; anyone can reload, edit the URL, or
replay a request with curl. What actually protects a page is the server checking
a credential on every request. Tahanan sends a signed JWT on every API call and
`requireAuth` verifies the signature, the account status, the token version and
the idle deadline before returning any data. History can therefore only show an
empty shell, never protected data.

**7. May the app's database account delete log rows?**
No. Log rows are evidence. `prevent_auth_events_change()` rejects `UPDATE` and
`DELETE` on `auth_events` for every role, and the API exposes no edit or delete
route. Retention is handled by an administrator with a separate maintenance
account, outside the app.

**8. CSRF with a token API.**
The handout expects a per-form CSRF token because PHP sessions ride cookies.
Tahanan authenticates with a bearer JWT that lives in memory and the device
keystore, so a foreign page cannot attach it. To keep the protection explicit
and testable, `csrfGuard` refuses any state-changing request whose browser
`Origin` is not the app's own origin (or an allowlisted one) and records
`CSRF_REJECTED`. Native Android requests carry no `Origin`; their protection is
the token itself.

**9. ID Number as primary key.**
The handout wants the ID Number to be the primary key. Tahanan's tables already
use UUID primary keys so that rooms, tenants, payments and logs can reference a
user safely, and a visible ID Number can be corrected without cascading. The ID
Number is therefore a **unique identity field** (`users.id_number UNIQUE`), and
a duplicate is refused with “This ID Number is already registered.” This is the
only intentional deviation from the letter of the handout.

**10. Idle timeout, twice.**
`requireAuth` compares `users.last_activity_at` with `IDLE_TIMEOUT_SECONDS=360`
and returns 401 `SESSION_IDLE`; the Flutter `IdleSessionGuard` warns at five
minutes and signs out at six, calling `/api/auth/logout-all` so the token is
dead even if the app is closed.

**11. Scheduling the monitoring script.**
Windows Task Scheduler → Create Task → Trigger “Daily, repeat every 15 minutes”
→ Action “Start a program”: `C:\Program Files\nodejs\node.exe` with arguments
`node_modules\tsx\dist\cli.mjs scripts/monitor.ts` and working directory
`C:\Users\caloy\StudioProjects\Tahanan\backend`. On Linux the same line goes in
cron as `*/15 * * * *`. The demo runs it by hand.

**12. Hashing vs encryption.**
Hashes are one-way and are used for passwords, security answers and OTP codes:
nothing ever needs to read them back. Encryption is reversible and is used only
for the Government ID, which must be shown to its owner and the house owner;
AES-256-GCM with a random IV and an auth tag protects both secrecy and integrity.

**13. Why the dashboard is a Flutter screen, not a web page.**
The whole system is one Flutter app (Android + web) with an Express API. The
dashboard is `lib/screens/admin/security_dashboard.dart`, visible only when the
signed-in account has `is_admin`. It is read-only by construction: the API has
no write route and the table rejects updates.

**14. “Hide JavaScript files” and what it really protects.**
The Flutter build ships compiled JavaScript that the browser must download, so
hiding it is impossible and pointless. Tahanan instead keeps **source** files
(`backend/src`) out of the served tree and protects data with server-side
authorisation. Obfuscating client code only slows an attacker down; the real
protection is that the server never trusts the client.
