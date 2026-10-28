# App log-in aligned with the IT 107 handout

The Flutter app and the portal now use the same authentication shape.

| Step | Portal (`it107-secure`) | App (`backend` + Flutter) |
|---|---|---|
| 1 | Username + password + CAPTCHA | Username + password + reCAPTCHA v2 (or the server challenge) |
| 2 | 6-digit email code | 6-digit email code |
| Session | Created only after the code | Created only after the code |
| Code rules | 5 min, 3 tries, single use, 60 s resend | Same |
| Lockout | 16 / 32 / 64 s | Existing account lockout |
| Idle timeout | 6 min | Existing session handling |

## Backend changes

- `sql/004_login_otp.sql` adds `users.username` (unique, case-insensitive) and
  `login_otps` (hashed code, expiry, attempts, used, resend count).
- `src/services/login-otp.service.ts` implements the handout's OTP rules.
- `POST /api/auth/login` now verifies username + password + CAPTCHA and returns
  `{ otpRequired, challengeId, maskedEmail, expiresIn, resendIn }` — **no tokens**.
- `POST /api/auth/login/verify-otp` verifies the code and only then issues tokens.
- `POST /api/auth/login/resend-otp` enforces the 60-second cooldown.
- `GET /api/auth/username-available` supports the live username check.
- Registration now requires a username (7–16 characters, starts with a letter,
  letters and digits only) and rejects duplicates with `USERNAME_TAKEN`.

Existing accounts were backfilled: `jamestermulato`, `jamester`,
`joritomulato`; all other accounts received unique placeholders.

## App changes

- Log-in field is **Username**; the Google email is only used to receive codes.
- `LoginOtpScreen` handles the code: expiry countdown, resend cooldown, three
  tries, and a “use a different account” escape.
- Saved accounts store the username as well as the email.
- Sign-up collects name, email, username, password and consent.
- “Remember this account” now only autofills; the code is still required.

## Still different

- Registration in the app still signs the user in immediately instead of
  requiring an email code first. The portal does require verification, which is
  what the handout grades.
