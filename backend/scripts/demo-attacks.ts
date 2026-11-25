/**
 * Live attack pack for the IT 107 demo.
 *
 * Runs the handout's attacker checks against a running local API and prints a
 * PASS/FAIL line for each. It only uses public endpoints, exactly like an
 * attacker would.
 *
 *   npx tsx scripts/demo-attacks.ts
 *
 * The IP-block test sends X-Forwarded-For with the reserved documentation
 * range 203.0.113.77, so the real demo machine is not locked out.
 */
import { query, pool } from "../src/config/db";

const BASE = process.env.DEMO_BASE ?? "http://127.0.0.1:8080";
const TEST_IP = "203.0.113.77";

interface Reply {
  status: number;
  body: any;
  headers: Headers;
}

let passed = 0;
let failed = 0;

function check(label: string, ok: boolean, detail: string) {
  if (ok) {
    passed++;
    console.log(`PASS  ${label} — ${detail}`);
  } else {
    failed++;
    console.log(`FAIL  ${label} — ${detail}`);
  }
}

async function call(
  path: string,
  init: RequestInit = {},
  ip?: string
): Promise<Reply> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  if (ip) headers.set("x-forwarded-for", ip);
  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  let body: any = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  return { status: res.status, body, headers: res.headers };
}

async function captcha() {
  const r = await call("/api/auth/captcha");
  const question: string = r.body?.question ?? "";
  const m = question.match(/(\d+)\s*([+-])\s*(\d+)/);
  if (!m) throw new Error(`unreadable captcha: ${question}`);
  const answer = m[2] === "+" ? Number(m[1]) + Number(m[3]) : Number(m[1]) - Number(m[3]);
  return { captchaId: r.body.id, captchaAnswer: String(answer) };
}

async function login(username: string, password: string, ip?: string) {
  const human = await captcha();
  return call(
    "/api/auth/login",
    {
      method: "POST",
      body: JSON.stringify({ username, password, ...human })
    },
    ip
  );
}

async function main() {
  console.log(`\nIT 107 attack pack — ${BASE}\n`);

  // P1 — SQL injection in the username field.
  {
    const r = await login("' OR '1'='1", "anything");
    check(
      "P1 SQL injection",
      r.status === 401 && r.body?.message === "Invalid username or password.",
      `status ${r.status}, message "${r.body?.message ?? ""}"`
    );
  }

  // P2 — script payload stored exactly as typed, never executed.
  {
    const payload = "<script>alert(1)</script>";
    const r = await login(payload, "anything");
    const logged = await query<{ n: number }>(
      `SELECT count(*)::int AS n FROM auth_events
        WHERE event_type = 'LOGIN_FAILED' AND username_typed = $1`,
      [payload]
    );
    check(
      "P2 XSS payload",
      r.status === 401 && (logged.rows[0]?.n ?? 0) > 0,
      `status ${r.status}, stored ${logged.rows[0]?.n ?? 0} log row(s) verbatim`
    );
  }

  // P4 / S9 — unknown user and wrong password look identical.
  {
    const unknown = await login("nosuchuser404", "anything");
    const known = await login("hand2372", "definitely-wrong", "203.0.113.78");
    check(
      "P4 username enumeration",
      unknown.status === known.status &&
        unknown.body?.message === known.body?.message,
      `unknown ${unknown.status} vs known ${known.status}, same message: ${unknown.body?.message === known.body?.message}`
    );
  }

  // P3 — foreign Origin on a state-changing call.
  {
    const r = await call("/api/auth/logout", {
      method: "POST",
      body: JSON.stringify({}),
      headers: { origin: "https://evil.example" }
    });
    check(
      "P3 CSRF (foreign Origin)",
      r.status === 403 && r.body?.error === "CSRF_REJECTED",
      `status ${r.status}, error ${r.body?.error ?? "none"}`
    );
  }

  // P8 — honeypot is accepted silently and creates nothing.
  {
    const marker = `HONEY-${Date.now()}`;
    const r = await call("/api/auth/register", {
      method: "POST",
      body: JSON.stringify({
        website: "http://spam.example",
        id_number: marker,
        first_name: "Bot"
      })
    });
    const created = await query<{ n: number }>(
      "SELECT count(*)::int AS n FROM users WHERE id_number = $1",
      [marker]
    );
    check(
      "P8 honeypot",
      r.status === 201 && (created.rows[0]?.n ?? 0) === 0,
      `status ${r.status}, accounts created: ${created.rows[0]?.n ?? 0}`
    );
  }

  // P5 — one IP, many accounts.
  {
    let last = 0;
    let blockedAt = 0;
    for (let i = 1; i <= 14; i++) {
      const r = await login(`probe${i}`, "wrong", TEST_IP);
      last = r.status;
      if (r.status === 429) {
        blockedAt = i;
        break;
      }
    }
    check(
      "P5 IP blocking",
      last === 429,
      `blocked on attempt ${blockedAt || "never"} (threshold 13/10 min)`
    );
  }

  // P12 — security headers.
  {
    const r = await call("/health");
    const frame = r.headers.get("x-frame-options");
    const sniff = r.headers.get("x-content-type-options");
    check(
      "P12 security headers",
      frame === "DENY" && sniff === "nosniff",
      `X-Frame-Options: ${frame}, X-Content-Type-Options: ${sniff}`
    );
  }

  // P9 / S11 — the activity log rejects UPDATE and DELETE.
  {
    let rejected = 0;
    for (const statement of [
      "UPDATE auth_events SET event_type = 'TAMPERED' WHERE id = (SELECT max(id) FROM auth_events)",
      "DELETE FROM auth_events WHERE id = (SELECT max(id) FROM auth_events)"
    ]) {
      try {
        await query(statement);
      } catch {
        rejected++;
      }
    }
    check(
      "P9 append-only log",
      rejected === 2,
      `${rejected}/2 UPDATE or DELETE statements rejected by the trigger`
    );
  }

  // Leave the demo account usable after the enumeration test.
  await query(
    "UPDATE users SET failed_login_count = 0, locked_until = NULL WHERE lower(username) = 'hand2372'"
  );

  const flags = await query<{ n: number }>(
    "SELECT count(*)::int AS n FROM security_flags WHERE flag_date = CURRENT_DATE"
  );
  console.log(`\n${passed} passed, ${failed} failed. Flags today: ${flags.rows[0]?.n ?? 0}.`);
  console.log(`Run "npx tsx scripts/monitor.ts" to turn these events into flags.\n`);
  await pool.end();
  process.exit(failed === 0 ? 0 : 1);
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
