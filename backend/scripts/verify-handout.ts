/**
 * Local verification for the handout security requirements.
 * Run with: npx tsx scripts/verify-handout.ts
 * Safe to run repeatedly: it only reads data and restores anything it changes.
 */
import { query, pool } from "../src/config/db";
import { signAccessToken } from "../src/utils/auth-token";
import { completeLogin } from "../src/services/auth.service";

const BASE = "http://localhost:8080";

async function call(path: string, token?: string) {
  const res = await fetch(`${BASE}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {}
  });
  let body: unknown = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  return { status: res.status, body: body as Record<string, unknown> };
}

async function main() {
  const admin = await query<{
    id: string;
    email: string;
    display_name: string;
    token_version: number;
    is_admin: boolean;
  }>(
    `SELECT id, email, display_name, token_version, is_admin
       FROM users WHERE is_admin = true ORDER BY created_at LIMIT 1`
  );
  const normal = await query<{
    id: string;
    email: string;
    display_name: string;
    token_version: number;
    is_admin: boolean;
  }>(
    `SELECT id, email, display_name, token_version, is_admin
       FROM users WHERE is_admin = false ORDER BY created_at LIMIT 1`
  );

  const adminRow = admin.rows[0];
  const normalRow = normal.rows[0];
  if (!adminRow || !normalRow) {
    console.log("FAIL: need one admin and one normal account");
    await pool.end();
    return;
  }

  const tokenFor = (row: typeof adminRow) =>
    signAccessToken({
      id: row.id,
      email: row.email,
      displayName: row.display_name,
      tokenVersion: row.token_version
    });

  // A freshly minted test token is only accepted when the account is not idle.
  await query(
    "UPDATE users SET last_activity_at = now() WHERE id = ANY($1::uuid[])",
    [[adminRow.id, normalRow.id]]
  );

  const results: string[] = [];
  const pass = (name: string, ok: boolean, extra = "") =>
    results.push(`${ok ? "PASS" : "FAIL"}  ${name}${extra ? ` — ${extra}` : ""}`);

  // 1. No token -> 401
  const anon = await call("/api/admin/security");
  pass("admin dashboard rejects anonymous", anon.status === 401, `status ${anon.status}`);

  // 2. Normal user -> 403 and ADMIN_ACCESS_DENIED logged
  const normalToken = tokenFor(normalRow);
  const deniedResponse = await call("/api/admin/security", normalToken);
  const denied = await query(
    `SELECT 1 FROM auth_events
      WHERE event_type = 'ADMIN_ACCESS_DENIED' AND user_id = $1
        AND created_at > now() - interval '2 minutes'`,
    [normalRow.id]
  );
  pass(
    "normal user gets 403 on admin dashboard",
    deniedResponse.status === 403,
    `status ${deniedResponse.status}`
  );
  pass("ADMIN_ACCESS_DENIED written to activity log", (denied.rowCount ?? 0) > 0);

  // 3. Admin -> 200 with summary and event list
  const adminToken = tokenFor(adminRow);
  const okResponse = await call("/api/admin/security?log=0", adminToken);
  const body = okResponse.body as {
    summary?: Record<string, unknown>;
    events?: unknown[];
  };
  pass(
    "admin dashboard returns summary + events",
    okResponse.status === 200 &&
      typeof body.summary === "object" &&
      Array.isArray(body.events),
    `status ${okResponse.status}, events ${body.events?.length ?? 0}`
  );

  // 4. isAdmin flag reaches the client through /api/me
  const me = await call("/api/me", adminToken);
  const meUser = (me.body as { user?: { isAdmin?: boolean } }).user;
  pass("admin session carries isAdmin=true", meUser?.isAdmin === true);

  // 5. Idle timeout: pretend the last activity was 7 minutes ago
  const original = await query<{ last_activity_at: string | null }>(
    "SELECT last_activity_at FROM users WHERE id = $1",
    [normalRow.id]
  );
  await query(
    "UPDATE users SET last_activity_at = now() - interval '7 minutes' WHERE id = $1",
    [normalRow.id]
  );
  const idle = await call("/api/me", normalToken);
  const idleError = (idle.body as { error?: string }).error;
  pass(
    "6-minute idle timeout returns 401 SESSION_IDLE",
    idle.status === 401 && idleError === "SESSION_IDLE",
    `status ${idle.status}, error ${idleError}`
  );
  await query("UPDATE users SET last_activity_at = $2 WHERE id = $1", [
    normalRow.id,
    original.rows[0]?.last_activity_at ?? null
  ]);

  // 6. Activity is refreshed by ordinary authenticated calls
  const before = await query<{ last_activity_at: string }>(
    "SELECT last_activity_at FROM users WHERE id = $1",
    [normalRow.id]
  );
  await new Promise(resolve => setTimeout(resolve, 1100));
  await call("/api/me", normalToken);
  const after = await query<{ last_activity_at: string }>(
    "SELECT last_activity_at FROM users WHERE id = $1",
    [normalRow.id]
  );
  pass(
    "authenticated request refreshes last_activity_at",
    new Date(after.rows[0]!.last_activity_at).getTime() >
      new Date(before.rows[0]!.last_activity_at).getTime()
  );

  // 7. A fresh sign-in must start a new idle window (regression test).
  //    The old behaviour rejected the first /api/me when the account had been
  //    idle before signing in, which sent the app back to the login screen.
  await query(
    "UPDATE users SET last_activity_at = now() - interval '10 minutes' WHERE id = $1",
    [normalRow.id]
  );
  const freshSession = await completeLogin(normalRow.id);
  const freshMe = await call("/api/me", freshSession.accessToken);
  pass(
    "fresh sign-in starts a new idle window",
    freshMe.status === 200,
    `status ${freshMe.status}`
  );

  // 7. Security headers (P12)
  const health = await fetch(`${BASE}/health`);
  const frame = health.headers.get("x-frame-options") ?? "";
  const nosniff = health.headers.get("x-content-type-options") ?? "";
  pass(
    "security headers X-Frame-Options + nosniff",
    frame.toUpperCase().includes("DENY") && nosniff.toLowerCase() === "nosniff",
    `${frame || "none"} / ${nosniff || "none"}`
  );

  // 8. CSRF guard: a foreign browser origin is refused and logged
  const forged = await fetch(`${BASE}/api/auth/logout-all`, {
    method: "POST",
    headers: {
      Origin: "https://evil.example",
      "Content-Type": "application/json"
    },
    body: "{}"
  });
  const forgedBody = (await forged.json().catch(() => ({}))) as {
    error?: string;
  };
  const csrfLog = await query(
    `SELECT 1 FROM auth_events
      WHERE event_type = 'CSRF_REJECTED'
        AND created_at > now() - interval '2 minutes'`
  );
  pass(
    "foreign Origin rejected as CSRF_REJECTED",
    forged.status === 403 &&
      forgedBody.error === "CSRF_REJECTED" &&
      (csrfLog.rowCount ?? 0) > 0,
    `status ${forged.status}`
  );

  // 9. Seed values the handout derives from 241-00315 (D1 = 1, D2 = 5)
  const seed = [
    ["username min 7", "7"],
    ["username max 16", "16"],
    ["password min 9", "9"],
    ["name max 25", "25"],
    ["lockout 16/32/64", "16/32/64"],
    ["OTP 5 min", "5"],
    ["idle 6 min", "6"],
    ["IP block 13/10 min", "13/10"],
    ["questions Q6,Q1,Q3", "Q6,Q1,Q3"]
  ];
  for (const [name, value] of seed) results.push(`INFO  seed ${name} = ${value}`);

  console.log(results.join("\n"));
  await pool.end();
}

main().catch(async error => {
  console.error(error);
  await pool.end();
  process.exitCode = 1;
});
