/**
 * Produces genuine security test data for the SQL dump:
 *   - 14 failed log-in attempts from this machine (crosses the seeded IP
 *     threshold of 13), which writes LOGIN_FAILED + IP_BLOCKED and an
 *     `ip_blocks` row.
 *   - Then unknown-username attempts so the activity log shows attacker-typed
 *     identifiers and the monitor can flag the IP.
 *
 * Run: npx tsx scripts/generate-test-data.ts
 * Follow with: npx tsx scripts/monitor.ts
 */
const BASE = "http://localhost:8080";

async function captcha() {
  const response = await fetch(`${BASE}/api/auth/captcha`);
  const body = (await response.json()) as { id: string; question: string };
  const parts = body.question.match(/(\d+)\s*([+-])\s*(\d+)/);
  if (!parts) throw new Error(`Unreadable CAPTCHA question: ${body.question}`);
  const answer =
    parts[2] === "+"
      ? Number(parts[1]) + Number(parts[3])
      : Number(parts[1]) - Number(parts[3]);
  return { captchaId: body.id, captchaAnswer: String(answer) };
}

async function main() {
  const usernames = ["ghost.test", "ghost.test2", "hand2372"];
  const statuses: string[] = [];

  for (let i = 0; i < 14; i++) {
    const human = await captcha();
    const response = await fetch(`${BASE}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username: usernames[i % usernames.length],
        password: `WrongPass${i}A`,
        ...human
      })
    });
    statuses.push(String(response.status));
  }

  console.log(`Failed log-in statuses: ${statuses.join(", ")}`);
  console.log(
    "Expected: eleven 401s, then 423/429 once the account lockout or the IP block trips."
  );
  console.log("Next: npx tsx scripts/monitor.ts");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
