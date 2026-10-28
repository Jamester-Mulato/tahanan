# Tahanan Local Full-Stack

## Architecture

Flutter Android client -> Tahanan Node/TypeScript API -> PostgreSQL

The PostgreSQL database can be the exact database already created with pgAdmin. pgAdmin itself is only the database management client; the backend connects to the PostgreSQL server.

## Database behavior

At backend startup:

1. Connect to PostgreSQL's `postgres` database.
2. Check whether `DATABASE_NAME` exists.
3. If missing and `DB_AUTO_CREATE=true`, create it.
4. Connect to the Tahanan database.
5. If the Tahanan schema is missing and `DB_AUTO_INIT_SCHEMA=true`, install `backend/sql/001_schema.sql`.
6. If the schema migration record exists, compare its SHA-256 checksum with the bundled schema.
7. If the checksum differs, stop safely with `DATABASE_SCHEMA_MISMATCH` and DO NOT overwrite the existing database.

Bundled schema checksum:

`a89b61052c03b714af6bafb38041a314d2c5f6ba0181ea2a3e0dbcbae2e468ae`

## Database setup

Copy `.env.example` to `.env` in `backend_parent/tahanan_backend` and point
`DATABASE_URL` at your local PostgreSQL:

```env
DATABASE_URL=postgresql://postgres:YOUR_DB_PASSWORD@localhost:5432/tahanan
```

Percent-encode special characters in the password (`@` → `%40`, `:` → `%3A`).

The database must exist before the backend can use it. Create it once in pgAdmin
or with:

```sql
CREATE DATABASE tahanan OWNER postgres;
```

Then apply the schema:

```powershell
npm run build
npm run db:init
```

The bundled schema is idempotent (`CREATE TABLE IF NOT EXISTS`), so re-running
it is safe. If a sign-in returns `DATABASE_UNAVAILABLE` or
`password authentication failed for user …`, the credentials in `DATABASE_URL`
are wrong — the API is otherwise healthy.

## Start backend

```powershell
cd backend_parent\tahanan_backend
Copy-Item .env.example .env   # skip if .env already exists
npm install
npm run dev
```

Verify database without starting HTTP:

```powershell
npm run db:verify
```

Backend health:

`http://localhost:8080/health`

## Start Flutter

From the Tahanan root:

```powershell
flutter pub get
flutter run
```

Android Emulator uses `http://10.0.2.2:8080`.
For a physical phone, replace the API URL with the PC's LAN IP using:

```text
flutter run --dart-define=TAHANAN_API_URL=http://192.168.x.x:8080
```

## Security notes

- Debug builds may call a plain-HTTP LAN backend. Release builds require an
  `https://` API URL (loopback hosts are still allowed for local testing).
- The access token is kept in platform secure storage, not SharedPreferences.
  Existing plain-text tokens are migrated automatically on first launch.
- The Android release manifest disables cleartext traffic and cloud backup.
- If the backend returns `401`, the app clears the stored token and returns to
  the sign-in screen.
- Rotate `JWT_SECRET` and use an explicit `CORS_ORIGINS` allowlist before
  exposing the API beyond your local network.

## Google authentication

Tahanan no longer uses Firebase. Flutter uses Google Sign-In directly and sends a Google credential to `/api/auth/google`, which the backend verifies before issuing a Tahanan JWT.

The credential differs by platform, and the backend accepts either:

| Platform | Credential | How the backend verifies it |
| --- | --- | --- |
| Android / iOS | `idToken` (JWT) | Signature checked locally against `GOOGLE_CLIENT_IDS` |
| Web | `accessToken` | Google's `tokeninfo` endpoint, which also confirms the token's `aud` is one of `GOOGLE_CLIENT_IDS` |

This is why the web flow works even though `google_sign_in_web`'s popup cannot return an ID token.

The web client ID is compiled in as a default
(`lib/core/app_config.dart`), so nothing needs to be passed for normal local
runs. Override it only when switching Google Cloud projects:

```powershell
flutter run --dart-define=TAHANAN_GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

The Google OAuth configuration must also have the correct Android package name/SHA-1 for the installed build.

## Web sign-in (Google OAuth)

Google only allows the web app to sign in from an **origin** (scheme + host +
port) that is registered on the OAuth client. `flutter run -d chrome` picks a
random port by default, which can never be registered reliably, so always pin
the port:

```powershell
flutter run -d chrome --web-port=5000 `
  --dart-define=TAHANAN_API_URL=http://localhost:8080
```

Then confirm the origin once in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

1. Open **APIs & Services → Credentials**.
2. Open the **OAuth 2.0 Client ID** whose type is **Web application**
   (this must be the same client ID as `AppConfig.googleWebClientId`).
3. Under **Authorized JavaScript origins**, make sure these are present:

   ```text
   http://localhost:5000
   http://127.0.0.1:5000
   ```

4. Under **Authorized redirect URIs**, add the same two values.
5. Enable the **People API** in the same project
   ([APIs & Services → Library → People API](https://console.cloud.google.com/apis/library/people.googleapis.com)).
   `google_sign_in_web` uses it to read the signed-in profile; without it the
   popup succeeds and the app fails with
   `People API has not been used in project …`.
6. Save, wait a minute for propagation, then hard-reload the page
   (`Ctrl` + `Shift` + `R`).

`localhost` and `127.0.0.1` are **different origins** to Google. Registering one
does not cover the other — if you only register `localhost`, always open
`http://localhost:5000`, never `http://127.0.0.1:5000`.

If the app is served on a different port, the registered origin must match that
port exactly. A stable port is more important than any specific port number.

For a production build, repeat this for the real site origin, e.g.
`https://tahanan.example.com`, and set the backend allowlist accordingly:

```env
CORS_ORIGINS=https://tahanan.example.com
```

Also make sure the backend verifies the same client ID:

```env
GOOGLE_CLIENT_IDS=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

### Web sign-in troubleshooting

| Message | Meaning | Fix |
| --- | --- | --- |
| `Error 400: origin_mismatch` | The page origin is not registered on the Web OAuth client. | Add the exact origin shown by **Trouble signing in?** on the login screen. |
| `redirect_uri_mismatch` | The redirect URI is not registered. | Add the same origin under **Authorized redirect URIs**. |
| `invalid_client` / `unauthorized_client` | The client ID is not a Web client, belongs to another project, or was deleted. | Create your own **Web application** OAuth client and pass its ID via `--dart-define`. |
| `idpiframe_initialization_failed` | The browser blocks Google's sign-in frame (cookies/tracking protection). | Allow third-party cookies for `accounts.google.com`, or try a normal Chrome profile. |
| `popup_closed_by_user` | The user closed the window. | Not an error — just try again. |
| `People API has not been used in project …` | The OAuth popup succeeded, but `google_sign_in_web` reads the profile from the People API, which is disabled in the project. | Enable **People API** in [APIs & Services → Library](https://console.cloud.google.com/apis/library/people.googleapis.com) for the project that owns the web client, wait a minute, then sign in again. |

The login screen's **Trouble signing in?** link shows the exact origin to
register and can copy it to the clipboard.

## Revised user model

There is no permanent owner/tenant role. After Google login:

```text
My Boarding Houses

Green Haven
OWNER

Another Boarding House
TENANT

+ Create BH
+ Join BH
```

A single Google account can own multiple BHs and be a tenant in other BHs.
