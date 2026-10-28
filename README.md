# Tahanan

A local full-stack Flutter Android + Node/TypeScript + PostgreSQL boarding-house management application.

## Current architecture

```text
Flutter Android
      |
      | HTTP locally / HTTPS in production
      v
Tahanan Backend
Node + TypeScript + Express
      |
      v
PostgreSQL
```

Firebase, Firestore, and Firebase Authentication were removed.

## Features implemented

- Direct Google Sign-In + backend Google ID-token verification
- Tahanan API JWT session
- Create boarding house
- Join boarding house using key/domain
- Per-boarding-house roles
- Multiple BH memberships per user
- Room capacities stored per room
- Calculated room occupancy/open slots
- Tenant records
- Google account association model
- Unassigned/rogue account listing/removal
- Monthly status schema
- Announcements
- Concerns and owner responses
- PostgreSQL schema auto-create/auto-init
- PostgreSQL schema checksum/drift safety check
- Light white-green Material 3 theme with Inter typography
- Access token stored in the platform secure keystore
- HTTPS-only API calls in release builds
- Backend rate limiting, strict CORS, and hardened JWT validation

## Security notes

- Release builds refuse plain-HTTP API URLs (loopback hosts are exempt for local testing).
- The access token is stored with `flutter_secure_storage` (Android Keystore / iOS Keychain / platform keystore) and legacy plain-text tokens are migrated and removed.
- API 401 responses clear the session and return the user to sign-in.
- Backend JWTs are HS256 with an issuer/audience check, and auth endpoints are rate-limited.

## Database safety

The backend never silently replaces a non-matching database. If the bundled schema checksum differs from the recorded migration checksum, startup stops.

Bundled schema checksum: `a89b61052c03b714af6bafb38041a314d2c5f6ba0181ea2a3e0dbcbae2e468ae`

## Start

See `LOCAL_SETUP.md`.

## IT 107 submission

The security requirements of the final laboratory project are documented in:

- `docs/submission/IT107_Tahanan_Final_Project_Documentation.docx` — the full
  written submission (proposal, threat model, design decisions, privacy note,
  error mapping, journal, test accounts, self-test and demo runbook), generated
  by `docs/build_submission_docx.py`.
- `backend/docs/` — the same material as Markdown sources.
- `backend/sql/tahanan_dump.sql` — PostgreSQL dump with every handout table and
  the seeded test records.
- `backend/scripts/seed-test-accounts.ts` — one admin and two demo users.
- `backend/scripts/seed-demo-evidence.ts` — repeatable test records for the
  activity log, IP blocks, password history and security flags.
- `backend/scripts/monitor.ts` — the four-pattern monitoring script.

Demo credentials and the seeded values are listed in the submission document,
section 8.
