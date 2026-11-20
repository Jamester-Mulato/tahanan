# Remote access with Tailscale

Goal: the Android app reaches the Tahanan backend from **any WiFi or mobile
data**, without a cable, port forwarding, or a public URL.

## What is in use

| Item | Value |
|---|---|
| Tailnet | `jamestermulato@gmail.com` (`tailaeee27.ts.net`) |
| Windows machine | `desktop-3qsl3r1` |
| Tailnet IPv4 | `100.68.121.7` |
| Public-to-tailnet HTTPS URL | `https://desktop-3qsl3r1.tailaeee27.ts.net` |
| App build flag | `--dart-define=TAHANAN_API_URL=https://desktop-3qsl3r1.tailaeee27.ts.net` |

`tailscale serve` proxies HTTPS (port 443) on the tailnet to
`http://127.0.0.1:8080`, so the app uses HTTPS and the release transport check
in `ApiClient` is satisfied. The traffic is private to the tailnet and encrypted
by WireGuard.

## One-time setup

1. Install Tailscale on Windows and Android.
2. Sign **both** devices in to the same personal account
   (`jamestermulato@gmail.com`). The school tailnet (`csucc.edu.ph`) does not
   allow `serve` — use the personal one.
3. On Windows:

   ```powershell
   & "C:\Program Files\Tailscale\tailscale.exe" serve --bg 8080
   & "C:\Program Files\Tailscale\tailscale.exe" serve status
   ```

4. Test from the phone (Tailscale toggled on):

   ```
   https://desktop-3qsl3r1.tailaeee27.ts.net/health
   ```

   Expected: `{"ok":true,...}`.

5. Build and install the APK:

   ```powershell
   flutter build apk --release `
     --dart-define=TAHANAN_API_URL=https://desktop-3qsl3r1.tailaeee27.ts.net
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

## Daily demo checklist

1. Start PostgreSQL (Windows service).
2. Start the backend: `cd backend; npm run dev` (or `npm start` after `npm run build`).
3. Confirm the Tailscale tray icon says **Connected**.
4. Open the URL above once in the phone browser.
5. Launch Tahanan and sign in.

Useful checks:

```powershell
tailscale status
tailscale serve status
Invoke-RestMethod https://desktop-3qsl3r1.tailaeee27.ts.net/health
```

## Notes and limits

- The laptop must be **awake and online**. Disable sleep during the demo.
- Disable Android battery optimisation for Tailscale so the tunnel stays up.
- `serve` is tailnet-only: nobody outside your tailnet can reach the API.
- If the machine name changes, the URL changes and the APK must be rebuilt with
  the new `TAHANAN_API_URL`.
- `app.set("trust proxy", 1)` is set in `backend/src/app.ts` so the activity log
  and IP blocking see the phone's tailnet IP instead of `127.0.0.1`.
- A Cloudflare quick tunnel was also tested and works
  (`cloudflared tunnel --url http://localhost:8080`), but its URL changes on
  every restart and it exposes the API publicly; Tailscale is preferred.
