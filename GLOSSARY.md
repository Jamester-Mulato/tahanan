# Glossary

Domain and design terms used in this repository. Keep entries short and use
them in code and commit messages.

## Domain

**Account** — one person's row in `users`, identified by a username and an
institutional or personal email. An account is `pending` until its registration
code is verified, then `active`.

**Sign-in decision** — the outcome of presenting a password: `ok`,
`ip-blocked`, `account-locked` or `rejected`. Owned by
`backend/src/services/sign-in.service.ts`; no route re-decides it.

**Credential policy** — the rules a password or username must satisfy. Owned by
`backend/src/services/credential-policy.ts`; the request layer, the registration
validator and the domain layer all call it.

**Lockout tier** — the seeded penalty applied on the 3rd, 6th and 9th-plus
consecutive failure (16 s, 32 s, 64 s). A successful sign-in resets the streak;
an expired lock does not.

**Session policy** — the runtime idle timeout stored in `app_settings` and read
by clients from `GET /api/config` at startup. Admin accounts are exempt.

**OTP challenge** — a one-time code bound to a purpose (`register`, `login`,
`reset`). Five-minute expiry, three attempts, resend cooldown.

## Design

**Module** — anything with an interface and an implementation.

**Interface** — everything a caller must know: types, invariants, error modes
and ordering constraints.

**Seam** — the place an interface lives, where behaviour can change without
editing callers.

**Deep** — a large implementation behind a small interface. **Shallow** is the
opposite and is a candidate for deletion.

**Locality / leverage** — bugs concentrate in one module / one interface serves
many callers.
