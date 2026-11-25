/**
 * Proves the account lockout is enforced by the server, not the screen.
 *
 *   npx tsx scripts/demo-lockout.ts
 *
 * It signs in with a wrong password (solving the CAPTCHA like the app does)
 * until the account is locked, then prints the API response and the database
 * state. It leaves the account locked for the tier-1 duration (16 s), which is
 * enough to show the countdown; it does not change any password.
 */
import { query, pool } from "../src/config/db";

const BASE = process.env.DEMO_BASE ?? "http://127.0.0.1:8080";
const USERNAME = process.env.DEMO_USER ?? "hand2372";

async function captcha() {
  const res = await fetch(`${BASE}/api/auth/captcha`);
  const body: any = await res.json();
  const m = String(body.question).match(/(\d+)\s*([+-])\s*(\d+)/);
  if (!m) throw new Error(`unreadable captcha: ${body.question}`);
  const answer = m[2] === "+" ? Number(m[1]) + Number(m[3]) : Number(m[1]) - Number(m[3]);
  return { captchaId: body.id, captchaAnswer: String(answer) };
}

async function attempt() {
  const human = await captcha();
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ username: USERNAME, password: "definitely-wrong", ...human })
  });
  const body: any = await res.json().catch(() => ({}));
  return { status: res.status, message: body.message, retryAfter: body.details?.retryAfter };
}

async function state() {
  const row = await query(
    "SELECT failed_login_count, locked_until FROM users WHERE lower(username) = lower($1)",
    [USERNAME]
  );
  return row.rows[0];
}

async function main() {
  console.log(`\nLockout check for "${USERNAME}"\n`);
  console.log("before:", await state());

  for (let i = 1; i <= 3; i++) {
    const r = await attempt();
    console.log(
      `attempt ${i}: ${r.status} — ${r.message ?? ""}` +
        (r.retryAfter ? ` (retryAfter ${r.retryAfter})` : "")
    );
    if (r.status === 423) break;
  }

  console.log("after: ", await state());
  console.log(
    "\nThe lock lives in users.locked_until, so a reload, a cleared cookie or a\n" +
      "re-enabled button cannot get past it. Wait for the countdown, then continue.\n"
  );
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
