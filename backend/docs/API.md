# Tahanan Backend API

Base URL:

`http://localhost:8080`

## Authentication

### Handout flows (password accounts)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/auth/recaptcha` | Which human check is active |
| GET | `/api/auth/captcha` | Math fallback challenge |
| POST | `/api/auth/register` | Validate every field, save as `pending`, send OTP |
| POST | `/api/auth/register/verify-otp` | Activate the account (`ACCOUNT_VERIFIED`) |
| POST | `/api/auth/register/resend-otp` | 60 s cooldown, 3 resends / 15 min |
| GET | `/api/auth/username-available?username=` | Live availability |
| POST | `/api/auth/login` | Username + password + CAPTCHA; sends the log-in OTP |
| POST | `/api/auth/login/verify-otp` | Session only after the code is correct |
| POST | `/api/auth/login/resend-otp` | Same resend rules |
| POST | `/api/auth/forgot-password/questions` | The user's seeded questions |
| POST | `/api/auth/forgot-password/answer` | Hashed answer, counts toward lockout |
| POST | `/api/auth/forgot-password/verify-otp` | Issues a single-use reset grant |
| POST | `/api/auth/forgot-password/reset` | New password, history check, e-mail alert |
| POST | `/api/auth/logout-all` | Bumps `token_version`, revokes every token |

`POST /api/auth/login` returns `{ otpRequired: true, challengeId, maskedEmail,
expiresIn, resendIn }`. No access token exists until the OTP is accepted.

Every protected request also enforces the seeded **6-minute idle timeout**
(`401 SESSION_IDLE`) and rejects a foreign browser `Origin` with
`403 CSRF_REJECTED`.

### Admin

`GET /api/admin/security?log=0&from=&to=&event=&username=&ip=`

Admin only. Returns `summary`, `hourly`, `topIps`, `flags`, `events` (latest 50)
and the applied filters. `log=0` suppresses `ADMIN_VIEWED_DASHBOARD` so the
60-second auto-refresh does not flood the log. A normal user gets
`403 ACCESS_DENIED` and the attempt is written as `ADMIN_ACCESS_DENIED`.

### POST /api/auth/google

Request:

```json
{
  "idToken": "GOOGLE_ID_TOKEN_FROM_FLUTTER"
}
```

The backend verifies the Google ID token directly with Google. Firebase is not used.

Response:

```json
{
  "accessToken": "TAHANAN_API_JWT",
  "user": {
    "id": "...",
    "email": "user@example.com",
    "displayName": "User Name",
    "avatarUrl": null
  }
}
```

Send the returned token to protected endpoints:

```http
Authorization: Bearer TAHANAN_API_JWT
```

## User / boarding houses

`GET /api/me`

Returns the current user and every active boarding-house membership.

`GET /api/boarding-houses/mine`

Returns the current user's active boarding houses.

`POST /api/boarding-houses`

Owner-capable user creates a new boarding house. Creating the BH makes the current user its owner.

Example:

```json
{
  "name": "Green Haven Boarding House",
  "rooms": [
    { "roomNumber": "101", "capacity": 4 },
    { "roomNumber": "102", "capacity": 4 },
    { "roomNumber": "103", "capacity": 2 },
    { "roomNumber": "104", "capacity": 4 },
    { "roomNumber": "105", "capacity": 4 }
  ],
  "academicYear": {
    "name": "2026-2027",
    "startsOn": "2026-06-01",
    "endsOn": "2027-06-01"
  }
}
```

`POST /api/boarding-houses/join`

A signed-in user joins an existing BH as a tenant.

```json
{
  "keyOrDomain": "GHBV-8X7K-2P9M"
}
```

A valid join creates/reactivates a tenant membership. It does not automatically create a tenant record or room assignment.

## Dashboard

`GET /api/dashboard/:boardingHouseId`

Returns room/tenant/open-slot/concern/unassigned-account counts derived from database state.

## Rooms

`GET /api/rooms/:boardingHouseId`

Available to active members.

`POST /api/rooms/:boardingHouseId`

Owner only.

`PATCH /api/rooms/:boardingHouseId/:roomId`

Owner only.

`DELETE /api/rooms/:boardingHouseId/:roomId`

Owner only; archives the room and refuses if active tenant assignments still exist.

## Tenants

`GET /api/tenants/:boardingHouseId`

Active members can read tenant records.

`POST /api/tenants/:boardingHouseId`

Owner only; creates a tenant record independently of Google authentication.

`GET /api/tenants/:boardingHouseId/unassigned`

Owner only; lists Google-authenticated tenant memberships that have no tenant association.

`POST /api/tenants/:boardingHouseId/associations`

Owner only.

```json
{
  "tenantId": "...",
  "userId": "...",
  "roomId": "..."
}
```

This explicitly associates a Google account with an existing tenant record and optionally assigns the tenant to a room.

`DELETE /api/tenants/:boardingHouseId/members/:userId`

Owner only; removes the target tenant account from the BH. It does not delete their Google account.

## Monthly status

`GET /api/status/:boardingHouseId/tenants/:tenantId`

`PUT /api/status/:boardingHouseId/tenants/:tenantId`

Owner-only updates:

```json
{
  "academicYearId": "...",
  "monthStart": "2026-09-01",
  "status": "paid"
}
```

Allowed statuses:

- `paid`
- `partial`
- `unpaid`

## Announcements

`GET /api/announcements/:boardingHouseId`

Active members can read published announcements.

`POST /api/announcements/:boardingHouseId`

Owner only.

```json
{
  "title": "Water Interruption Notice",
  "message": "There will be a water interruption..."
}
```

## Concerns

`GET /api/concerns/:boardingHouseId`

Owners see all concerns. Tenants see only concerns associated with their tenant record.

`POST /api/concerns/:boardingHouseId`

Tenant-capable endpoint.

Example:

```json
{
  "roomId": "...",
  "category": "maintenance",
  "subject": "Leaky faucet in the kitchen",
  "details": "The faucet keeps leaking."
}
```

`PATCH /api/concerns/:boardingHouseId/:concernId`

Owner only.

```json
{
  "status": "in_progress",
  "ownerResponse": "Maintenance will check this tomorrow."
}
```

Allowed statuses:

- `open`
- `in_progress`
- `resolved`

Attachments are represented through database metadata for now:

`POST /api/concerns/:boardingHouseId/:concernId/attachments`

Actual binary/object-storage upload can be added separately.

## Critical architecture rules

- No Firebase.
- No Firestore.
- No Firebase Authentication.
- No UI code.
- No Flutter code.
- PostgreSQL is the application database.
- Google identity is verified directly by the backend.
- Tahanan signs its own API JWT after successful Google verification.
- User role is per boarding house membership.
- Room capacity is per room.
- Room occupancy is derived from actual assignments.
- Google account, tenant record, and room assignment are distinct concepts.
