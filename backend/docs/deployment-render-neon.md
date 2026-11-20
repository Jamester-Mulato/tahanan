# Deploying Tahanan: Render + Neon

The API is a Node/Express service; the database is managed Postgres. Render
runs the API, Neon stores the data. The Flutter app (Android / web) only needs
the public HTTPS URL of the Render service.

```
Flutter app  ──HTTPS──▶  Render web service (Express)  ──TLS──▶  Neon Postgres
```

---

## 1. Create the Neon database

1. Sign in at <https://console.neon.tech> and create a project
   (region: **Singapore** for the Philippines).
2. Neon creates a database named `neondb` (or the name you choose) and a role.
3. Open **Connect** and copy the **pooled** connection string — the host
   contains `-pooler`, for example:

   ```
   postgresql://tahanan:secret@ep-cool-name-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
   ```

4. Keep it handy; this is `DATABASE_URL` on Render. Do **not** commit it.

Nothing else to do in Neon: the API creates its own tables on first boot when
`DB_AUTO_INIT_SCHEMA=true`.

---

## 2. Put the code on GitHub

From the project root:

```powershell
git init
git add .
git commit -m "Tahanan: app + API ready for deployment"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

The root `.gitignore` and `backend/.gitignore` already exclude
`node_modules/`, `dist/`, `.env` and build output. Never commit `backend/.env`.

---

## 3. Create the Render service

The repository contains `render.yaml`, so the fastest path is a Blueprint:

1. Render dashboard → **New** → **Blueprint** → pick the repository.
2. Render reads `render.yaml` and proposes one service, `tahanan-api`:
   - root directory: `backend`
   - build: `npm ci --include=dev && npm run build`
   - start: `npm start`
   - health check: `/health`
3. Apply, then fill the secrets marked `sync: false` (section 4).

If you prefer a manual Web Service instead of the Blueprint:

| Setting        | Value                        |
| -------------- | ---------------------------- |
| Language       | Node                         |
| Root directory | `backend`                    |
| Build command  | `npm ci --include=dev && npm run build`    |
| Start command  | `npm start`                  |
| Health check   | `/health`                    |
| Instance       | Free                         |

`PORT` is supplied by Render; the API reads it automatically.

---

## 4. Environment variables

| Key                     | Value                                                                 |
| ----------------------- | --------------------------------------------------------------------- |
| `NODE_ENV`              | `production`                                                          |
| `DATABASE_URL`          | Neon pooled connection string                                         |
| `DATABASE_SSL`          | `true`                                                                |
| `DB_AUTO_CREATE`        | `false` (Neon created the database)                                   |
| `DB_AUTO_INIT_SCHEMA`   | `true` (creates the schema on first boot)                             |
| `DB_VERIFY_SCHEMA`      | `true`                                                                |
| `JWT_SECRET`            | 32+ random chars — see generator below                                |
| `ENCRYPTION_KEY`        | 32 random bytes, base64 — see generator below                         |
| `GOOGLE_CLIENT_IDS`     | your Google OAuth client ID(s), comma-separated                       |
| `CORS_ORIGINS`          | browser origin(s) of the web app, e.g. `https://tahanan-web.onrender.com` |
| `APP_PUBLIC_URL`        | same public web URL (used in security-alert emails)                   |
| `RECAPTCHA_ENABLED`     | `true`                                                                |
| `RECAPTCHA_SITE_KEY`    | Google reCAPTCHA v2 site key                                          |
| `RECAPTCHA_SECRET_KEY`  | Google reCAPTCHA v2 secret key                                        |
| `BREVO_API_KEY`         | Brevo HTTPS API key (required on Render's free plan — see below)      |
| `SMTP_*`                | Gmail address + **app password** (local or paid hosts only)            |
| `IDLE_TIMEOUT_SECONDS`  | `360` (defaults match the handout)                                    |

Generate the two secrets locally:

```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"   # JWT_SECRET
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"      # ENCRYPTION_KEY
```

`ENCRYPTION_KEY` must decode to exactly 32 bytes; the base64 form above does.

### reCAPTCHA

The widget page is served by the API at `/recaptcha` and is opened inside the
app. In the [reCAPTCHA admin console](https://www.google.com/recaptcha/admin),
add the Render hostname (for example `tahanan-api.onrender.com`) and your web
app's hostname to the key's allowed domains, next to `localhost`.

### Mail on Render

Render's **free plan blocks outbound SMTP** (ports 25, 465 and 587), so Gmail
SMTP times out there even though the same credentials work locally. The API
therefore sends through **Brevo's HTTPS API** whenever `BREVO_API_KEY` is set:

1. Create a free account at <https://app.brevo.com> (300 emails/day).
2. **Senders & Domains** → add and verify the sender address. It must be the
   email inside `SMTP_FROM`, e.g. `jamestermulato@gmail.com`.
3. **SMTP & API → API Keys** → create a key (`xkeysib-...`).
4. Add it on Render as `BREVO_API_KEY` and redeploy.

Without any mail configuration the OTP is only printed in the Render log
(`[dev-mail] ...`), which still lets you sign in during a demo.

---

## 5. First boot

Open **Logs** on Render. A healthy first boot shows:

```
[DB] schema installed
[DB] handout baseline ensured
Tahanan API running at http://localhost:10000
```

Later boots show `[DB] schema verified: MATCH` followed by
`[DB] handout baseline ensured`. `001_schema.sql` is the original base schema;
`008_baseline_handout.sql` is re-run on every boot and is idempotent, so both a
brand-new Neon database and an upgraded local one end up with the same tables
and columns. Restarts and redeploys keep the data.

Smoke test from your machine:

```powershell
curl.exe https://tahanan-api.onrender.com/health
# {"ok":true,"service":"tahanan-backend","environment":"production"}
```

Then register an account in the app (or via the API). The first account can
create a boarding house and becomes its owner.

Optional: load the sample house for screenshots by running
`backend/sql/002_seed.sql` in the Neon SQL editor. It uses Google-only sample
users, so prefer registering real accounts for grading.

---

## 6. Point the clients at Render

The API URL is a `--dart-define`, with a runtime override in
**More → Server address**.

**Android APK**

```powershell
flutter build apk --release `
  --dart-define=TAHANAN_API_URL=https://tahanan-api.onrender.com
```

**Flutter web**

```powershell
flutter build web --release `
  --dart-define=TAHANAN_API_URL=https://tahanan-api.onrender.com
```

If the web build is also hosted on Render (Static Site, publish directory
`build/web`), set:

- `CORS_ORIGINS=https://<web-service>.onrender.com`
- `APP_PUBLIC_URL=https://<web-service>.onrender.com`

Native clients send no `Origin` header, so they are unaffected by
`CORS_ORIGINS`; browsers are.

No APK rebuild is strictly required: open the app, go to **More → Server
address**, paste the Render URL and save. The APK define just makes it the
default for a fresh install.

---

## 7. Free-tier notes

- **Spin-down:** the free instance sleeps after ~15 minutes idle; the next
  request takes 30–60 s to wake. Open the site once before a demo.
- **Ephemeral disk:** `backend/uploads` (concern photos/videos) is wiped on
  every deploy/restart. Files are fine for a live demo, but not durable
  storage. For permanence, move uploads to S3/Cloudinary or store them as
  bytea rows.
- **One instance:** the in-memory throttle/cooldown maps and the schema-first
  boot assume a single instance. Keep the free single instance; scale later by
  moving throttles to Postgres/Redis.
- **HTTPS only:** Render terminates TLS; the app's server-address validator
  accepts `https://` for non-loopback hosts, which matches this setup.

---

## 8. Redeploys

Push to `main`; Render rebuilds and restarts automatically.

Additive SQL migrations (`004`, `006`, `007`) are applied on boot when their
columns/tables are absent, so a redeploy against an older database is safe.
`DB_VERIFY_SCHEMA` refuses to run if `sql/001_schema.sql` no longer matches the
checksum stored in `schema_migrations`.
