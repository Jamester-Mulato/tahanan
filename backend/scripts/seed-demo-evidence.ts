/**
 * Adds repeatable TEST RECORDS to the local database so the submission SQL dump
 * demonstrates every handout table and the dashboard has something to show.
 *
 * This is seed data for a school demo, not a real attack log. Every row it
 * creates is marked with details.source = "demo-seed" and uses the reserved
 * documentation range 203.0.113.0/24 for IP addresses.
 *
 * Run: npx tsx scripts/seed-demo-evidence.ts
 * Then: npx tsx scripts/monitor.ts   (writes the security_flags rows)
 */
import { query, pool } from "../src/config/db";
import { hashPassword } from "../src/utils/password";

const TEST_NET = ["203.0.113.10", "203.0.113.11", "203.0.113.12", "203.0.113.13", "203.0.113.14"];
const UA = {
  attacker: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) curl/8.7.1",
  browser: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0 Safari/537.36",
  mobile: "Tahanan/1.0 (Android 14; SM-A155F)"
};

async function idOf(username: string): Promise<string | null> {
  const row = await query<{ id: string }>("SELECT id FROM users WHERE lower(username) = lower($1)", [username]);
  return row.rows[0]?.id ?? null;
}

async function event(input: {
  type: string;
  email?: string | null;
  usernameTyped?: string | null;
  userId?: string | null;
  ip?: string | null;
  ua?: string;
  details?: Record<string, unknown>;
  minutesAgo?: number;
}) {
  await query(
    `INSERT INTO auth_events
       (event_type, user_id, email, username_typed, ip_address, user_agent, details, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, now() - ($8 || ' minutes')::interval)`,
    [
      input.type,
      input.userId ?? null,
      input.email ?? null,
      input.usernameTyped ?? null,
      input.ip ?? null,
      input.ua ?? UA.attacker,
      JSON.stringify({ source: "demo-seed", ...(input.details ?? {}) }),
      String(input.minutesAgo ?? 0)
    ]
  );
}

async function main() {
  const hand2372 = await idOf("hand2372");
  const devicetest = await idOf("devicetest");
  const admin = await idOf("tahananadmin");

  if (!hand2372 || !devicetest || !admin) {
    throw new Error("Run scripts/seed-test-accounts.ts first.");
  }

  // 1. One IP over the seeded threshold (13 failures in 10 minutes).
  for (let i = 0; i < 15; i++) {
    await event({
      type: "LOGIN_FAILED",
      email: `+probe${i}@example.com`,
      usernameTyped: `probe${i}`,
      ip: TEST_NET[0],
      details: { reason: "wrong_password" },
      minutesAgo: 30 - i
    });
  }

  // 2. One account targeted from three different IPs.
  for (const [i, ip] of TEST_NET.slice(1, 4).entries()) {
    for (let n = 0; n < 2; n++) {
      await event({
        type: "LOGIN_FAILED",
        email: "jamestermulato+h2372@gmail.com",
        usernameTyped: "hand2372",
        userId: hand2372,
        ip,
        details: { reason: "wrong_password" },
        minutesAgo: 45 + i * 3 + n
      });
    }
  }

  // 3. OTP guessing: six wrong codes inside ten minutes.
  for (let i = 0; i < 6; i++) {
    await event({
      type: "OTP_FAILED",
      email: "jamestermulato+h2372@gmail.com",
      usernameTyped: "hand2372",
      userId: hand2372,
      ip: TEST_NET[2],
      details: { purpose: "login" },
      minutesAgo: 12 - i
    });
  }

  // 4. Off-hours successful log-in (02:15 Philippine time).
  await query(
    `INSERT INTO auth_events
       (event_type, user_id, email, username_typed, ip_address, user_agent, details, created_at)
     VALUES ('LOGIN_SUCCESS', $1, $2, 'devicetest', $3, $4,
             '{"source":"demo-seed","note":"off-hours sample"}'::jsonb,
             (date_trunc('day', now() AT TIME ZONE 'Asia/Manila') + interval '2 hours 15 minutes')
               AT TIME ZONE 'Asia/Manila')`,
    [devicetest, "jamestermulato+device@gmail.com", TEST_NET[3], UA.mobile]
  );

  // 5. A few normal events so the 24-hour chart is not empty.
  for (let i = 0; i < 6; i++) {
    await event({
      type: "LOGIN_SUCCESS",
      email: "jamestermulato+device@gmail.com",
      usernameTyped: "devicetest",
      userId: devicetest,
      ip: TEST_NET[3],
      ua: UA.browser,
      details: { provider: "password" },
      minutesAgo: 120 + i * 95
    });
  }
  await event({ type: "ADMIN_VIEWED_DASHBOARD", userId: admin, email: "jamestermulato+admin@gmail.com", ip: TEST_NET[4], ua: UA.browser, minutesAgo: 5 });

  // 6. IP blocks, including one that is active right now.
  const blocks: Array<[string, number, string]> = [
    [TEST_NET[0], 600, "15 failures in 10 minutes"],
    [TEST_NET[1], 600, "6 failures in 10 minutes"],
    [TEST_NET[2], 420, "6 wrong OTP codes in 10 minutes"],
    [TEST_NET[3], -90, "13 failures in 10 minutes (expired sample)"],
    [TEST_NET[4], -1440, "13 failures in 10 minutes (expired sample)"]
  ];
  for (const [ip, seconds, reason] of blocks) {
    await query(
      `INSERT INTO ip_blocks (ip_address, blocked_until, reason)
       VALUES ($1, now() + ($2 || ' seconds')::interval, $3)
       ON CONFLICT (ip_address) DO UPDATE
         SET blocked_until = EXCLUDED.blocked_until, reason = EXCLUDED.reason`,
      [ip, String(seconds), `${reason} [demo-seed]`]
    );
  }

  // 7. Password history (five distinct example hashes, never the demo password).
  const historical = ["OldPass#2024", "OlderPass#2023", "Tenancy#2022", "Bahay#2021", "Tahanan#2020"];
  for (const [i, password] of historical.entries()) {
    await query(
      `INSERT INTO password_history (user_id, password_hash, created_at)
       VALUES ($1, $2, now() - ($3 || ' days')::interval)`,
      [hand2372, await hashPassword(password), String(30 + i * 20)]
    );
  }

  const counts = await query(
    `SELECT
       (SELECT count(*)::int FROM users) users,
       (SELECT count(*)::int FROM auth_events) events,
       (SELECT count(*)::int FROM login_otps) otps,
       (SELECT count(*)::int FROM security_answers) answers,
       (SELECT count(*)::int FROM password_history) history,
       (SELECT count(*)::int FROM ip_blocks) blocks`
  );
  console.log("Test records added. Current counts:", counts.rows[0]);
  console.log("Now run: npx tsx scripts/monitor.ts");
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
