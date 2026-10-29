# Tahanan Backend

A backend-only implementation for the Tahanan boarding-house management app.

This package intentionally contains **no Flutter UI and no Firebase**.

## Architecture

```text
Flutter Android
    |
    | Google ID token + Tahanan API JWT
    v
Tahanan Backend (Node.js + TypeScript + Express)
    |
    v
PostgreSQL
```

Google is used only as the external identity provider. The backend verifies Google ID tokens directly with Google's OAuth libraries and then creates its own signed access token.

## Role model

A user's role is scoped to a boarding house.

```text
User A
  -> Green Haven -> owner
  -> Another BH   -> tenant
  -> Third BH     -> owner
```

Do not put a global `owner`/`tenant` flag on the user.

## Core data model

```text
users
boarding_houses
boarding_house_memberships
rooms
tenants
tenant_account_associations
tenant_room_assignments
academic_years
tenant_monthly_statuses
announcements
concerns
concern_attachments
```

## Start PostgreSQL

```bash
docker compose up -d postgres
```

The first container initialization loads:

- `sql/001_schema.sql`
- `sql/002_seed.sql`

To use a clean database later:

```bash
docker compose down -v
docker compose up -d postgres
```

## Configure backend

Copy:

```text
.env.example -> .env
```

Set at minimum:

```env
DATABASE_URL=postgresql://tahanan:tahanan_password@localhost:5432/tahanan
GOOGLE_CLIENT_IDS=...
JWT_SECRET=use-a-long-random-secret-at-least-32-characters
```

## Install and run

```bash
npm install
npm run dev
```

Build:

```bash
npm run build
```

Check types:

```bash
npm run check
```

Run production build:

```bash
npm start
```

Health check:

```text
GET http://localhost:8080/health
```

## Google authentication

The Flutter app should perform Google Sign-In and pass the resulting Google ID token to:

```text
POST /api/auth/google
```

The backend does not trust a user-supplied email/name as authentication.

It verifies the Google token, upserts the local `users` row, and returns a Tahanan access token.

## Important security behavior

### Join

A valid BH key/domain creates an active `tenant` membership.

It does **not** automatically create a tenant record.

### Unassigned account

After joining:

```text
Google account
    -> BH tenant membership
    -> no tenant_account_associations row
    -> unassigned account
```

Owners can associate or remove it.

### Remove

Removing a tenant account changes only its BH membership to `removed`.

The Google account itself is not deleted.

### Room capacity

PostgreSQL enforces active room capacity.

The API also treats room occupancy as derived information.

### Owner/tenant permissions

The backend checks the authenticated Tahanan JWT and the current BH membership before protected operations.

Do not rely on Flutter UI visibility as authorization.

## Current scope

Included:

- Google ID token verification without Firebase
- Tahanan API JWTs
- PostgreSQL
- Per-BH owner/tenant memberships
- BH creation and joining
- Room management
- Tenant records
- Google-account/tenant association
- Unassigned account removal
- Room assignments
- Academic years
- Monthly tenant status
- Announcements
- Concerns
- Concern responses
- Concern attachment metadata
- Dashboard views
- Database constraints/triggers/indexes

Not included yet:

- Flutter UI
- Actual object-storage upload implementation
- Push notifications
- Email/SMS notifications
- Advanced audit log
- Rate limiting/abuse protection (currently in-memory throttles)

These can be added later without changing the fundamental data model.

## Deployment

The API runs on Render with a Neon Postgres database. Step-by-step instructions
are in [docs/deployment-render-neon.md](docs/deployment-render-neon.md); the
repository root ships a `render.yaml` blueprint (service root: `backend`).