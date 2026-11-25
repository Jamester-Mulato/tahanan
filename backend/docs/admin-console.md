# Admin console

A standalone website for accounts with `users.is_admin = true`. It is **not**
part of the Flutter app — the app only reports client errors to it.

- Local: <http://localhost:8080/admin>
- Tailnet: <https://desktop-3qsl3r1.tailaeee27.ts.net/admin>

The page signs in with the same admin credentials as the app (username,
password, then the 6-digit email code). Non-admin accounts are refused after
the OTP step, and every `/api/admin/console` route re-checks `is_admin` on the
server. On Tailscale the site is reachable only from devices on the tailnet.

Everything it does goes through `/api/admin/console`; every privileged action
is appended to `admin_audit` with the acting admin, IP and timestamp.

## Tabs

### Overview
Live counters (users, admins, houses, rooms, tenants, announcements, concerns,
client errors, auth events), database size, PostgreSQL/Node versions, uptime,
the **session policy**, and the latest admin actions.

**Session policy** — idle timeout and countdown warning, in seconds. Saving
applies to the server immediately; **refresh the client** (web page or app) and
it fetches the new values from `/api/config`, so no rebuild or restart is
needed. The same values are enforced server-side (`SESSION_IDLE`).

### Database
- **SQL console** — runs any statement as the database role, with a 15-second
  statement timeout. `SELECT` results show up to 500 rows. Statements that are
  not `SELECT/SHOW/EXPLAIN/WITH` ask for confirmation first.
- **Tables** — every table in `public`, tap one to inspect its columns and the
  first 50 rows.

### Logs
- **Client errors** — uncaught errors reported by the Flutter app, newest
  first: message, account, platform, app version, screen, stack trace, IP.
  Clear them all with one tap.
- **Server log** — the tail of `backend/logs/error.log` (unexpected 500s).

### Users
Every account with status, admin flag, owned houses and membership count.
Per user:

- Make admin / remove admin (you cannot demote yourself)
- Disable / enable (bumps `token_version`, so every session dies)
- Sign out everywhere
- Delete account — removes the user, the houses they own, and all content in
  them; references in other houses are handed to the acting admin; the audit
  log keeps the event.

## API surface

All routes require `Authorization: Bearer <JWT>` for an admin account.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/admin/console/overview` | counters + versions |
| GET | `/api/admin/console/tables` | table list |
| GET | `/api/admin/console/tables/:table` | columns + rows (`limit`, `offset`) |
| POST | `/api/admin/console/sql` | `{ "sql": "..." }` |
| GET | `/api/admin/console/error-log` | `lines` (max 500) |
| GET | `/api/admin/console/client-errors` | reports (`limit`, `offset`, `username`) |
| DELETE | `/api/admin/console/client-errors` | clear reports |
| GET | `/api/admin/console/users` | accounts |
| PATCH | `/api/admin/console/users/:id` | `{ "status": "...", "is_admin": true }` |
| POST | `/api/admin/console/users/:id/logout-all` | revoke sessions |
| DELETE | `/api/admin/console/users/:id` | delete account |
| GET | `/api/admin/console/sessions` | refresh sessions |
| DELETE | `/api/admin/console/sessions/:id` | revoke one |
| GET | `/api/admin/console/ip-blocks` | active blocks |
| DELETE | `/api/admin/console/ip-blocks?ip=` | clear one / all |
| GET | `/api/admin/console/audit` | admin audit trail |

## Client error reporting

`POST /api/client-errors` accepts unauthenticated reports (login-screen
crashes included). Payload is capped at 2 KB for the message and 12 KB for the
stack, rate-limited to 30 per minute per IP, and linked to the account when a
valid bearer token is present.

The Flutter app installs the reporter in `lib/main.dart`:
`FlutterError.onError` and `PlatformDispatcher.onError` both forward to it.
Duplicates are dropped for a minute and no more than 20 reports are sent per
minute, so a loop cannot flood the database.

Rows live in `client_error_logs` (Postgres), so they survive restarts; the
server log file does not survive a Render redeploy.
