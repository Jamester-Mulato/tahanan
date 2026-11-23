# Seed table — student 241-00315

D2 = last digit = **5**. D1 = second-to-last digit = **1**.

| Seed parameter | Formula | Mine |
|---|---|---|
| Minimum username length | 6 + (D1 mod 3) | **7** |
| Maximum username length | 16 + (D2 mod 5) | **16** |
| Minimum password length | 8 + (D2 mod 4) | **9** |
| Maximum length of each name field | 20 + D2 | **25** |
| Failed log-ins before “Forgot Password?” appears | 2 + (D1 mod 2) | **3** |
| Lockout tier 1 | 15 + D1 seconds | **16 s** |
| Lockout tier 2 | 30 + (2 × D1) seconds | **32 s** |
| Lockout tier 3 | 60 + (4 × D1) seconds | **64 s** |
| OTP expiry | 3 + (D2 mod 3) minutes | **5 min** |
| Idle session timeout | 5 + (D1 mod 5) minutes | **6 min** |
| IP block threshold (failures in 10 min, any account) | 8 + D2 | **13 attempts** |
| IP block duration | fixed | **10 min** |
| Question A | Q[(D2 mod 8) + 1] | **Q6** — first song learned by heart |
| Question B | Q[((D2 + 3) mod 8) + 1] | **Q1** — first pet |
| Question C | Q[((D2 + 5) mod 8) + 1] | **Q3** — favorite high-school teacher |

Where each value lives:

| Value | File |
|---|---|
| Username 7–16 | `backend/src/security/registration.ts`, `backend/src/services/auth.service.ts` |
| Password min 9 / max 64 | same files |
| Name max 25 | `backend/src/security/registration.ts` |
| Forgot link after 3 | `lib/screens/login.dart` |
| Lockout 16 / 32 / 64 | `backend/src/config/env.ts` |
| OTP 5 min | `backend/src/services/login-otp.service.ts` |
| Idle 6 min | `backend/src/config/env.ts` (`IDLE_TIMEOUT_SECONDS=360`), `lib/widgets/idle_session_guard.dart` |
| IP block 13 / 10 min | `backend/src/config/env.ts`, `backend/src/services/throttle.service.ts` |
| Questions Q6/Q1/Q3 | `backend/src/security/questions.ts` |
