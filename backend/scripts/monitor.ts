/**
 * IT 107 monitoring script (handout section 14).
 * Run: npx tsx scripts/monitor.ts
 */
import { query, pool } from "../src/config/db";
import { env } from "../src/config/env";

interface Finding {
  pattern: string;
  target: string;
  severity: string;
  details: string;
  line: string;
}

async function main() {
  const scanned = await query<{ n: number }>(
    "SELECT count(*)::int AS n FROM auth_events WHERE created_at > now() - interval '24 hours'"
  );

  const findings: Finding[] = [];

  const ipOver = await query<{ ip_address: string; failures: number; users: number }>(
    `SELECT ip_address, count(*)::int AS failures,
            count(DISTINCT email)::int AS users
       FROM auth_events
      WHERE event_type = 'LOGIN_FAILED'
        AND created_at > now() - interval '24 hours'
        AND ip_address IS NOT NULL
      GROUP BY ip_address
     HAVING count(*) >= $1
      ORDER BY failures DESC`,
    [env.IP_BLOCK_THRESHOLD]
  );
  for (const row of ipOver.rows) {
    findings.push({
      pattern: "IP_OVER_THRESHOLD",
      target: row.ip_address,
      severity: "HIGH",
      details: `${row.failures} failures, ${row.users} usernames`,
      line: `[HIGH] IP over threshold   ${row.ip_address}   ${row.failures} failures, ${row.users} usernames`
    });
  }

  const targeted = await query<{ email: string; ips: number; failures: number }>(
    `SELECT email, count(DISTINCT ip_address)::int AS ips, count(*)::int AS failures
       FROM auth_events
      WHERE event_type = 'LOGIN_FAILED'
        AND created_at > now() - interval '24 hours'
        AND email IS NOT NULL
      GROUP BY email
     HAVING count(DISTINCT ip_address) >= 3
      ORDER BY ips DESC`
  );
  for (const row of targeted.rows) {
    findings.push({
      pattern: "ACCOUNT_TARGETED",
      target: row.email,
      severity: "MED",
      details: `failures from ${row.ips} IPs (${row.failures} attempts)`,
      line: `[MED ] Account targeted    ${row.email}   failures from ${row.ips} IPs`
    });
  }

  const otpGuessing = await query<{ target: string; failures: number }>(
    `SELECT COALESCE(email, user_id::text, 'unknown') AS target, count(*)::int AS failures
       FROM auth_events
      WHERE event_type = 'OTP_FAILED'
        AND created_at > now() - interval '10 minutes'
      GROUP BY 1
     HAVING count(*) >= 5`
  );
  for (const row of otpGuessing.rows) {
    findings.push({
      pattern: "OTP_GUESSING",
      target: row.target,
      severity: "MED",
      details: `${row.failures} wrong OTPs in 10 minutes`,
      line: `[MED ] OTP guessing       ${row.target}   ${row.failures} wrong OTPs in 10 min`
    });
  }

  const offHours = await query<{ email: string; created_at: string }>(
    `SELECT email, created_at
       FROM auth_events
      WHERE event_type IN ('LOGIN_SUCCESS','LOGIN_SUCCEEDED')
        AND created_at > now() - interval '24 hours'
        AND extract(hour FROM (created_at AT TIME ZONE 'Asia/Manila')) < 5`
  );
  for (const row of offHours.rows) {
    findings.push({
      pattern: "OFF_HOURS_LOGIN",
      target: row.email ?? "unknown",
      severity: "MED",
      details: `successful login at ${row.created_at}`,
      line: `[MED ] Off-hours login    ${row.email}   at ${row.created_at}`
    });
  }

  let written = 0;
  let existing = 0;
  for (const finding of findings) {
    const result = await query(
      `INSERT INTO security_flags (pattern, target, severity, details, flag_date)
       VALUES ($1, $2, $3, $4, CURRENT_DATE)
       ON CONFLICT (pattern, target, flag_date) DO NOTHING
       RETURNING id`,
      [finding.pattern, finding.target, finding.severity, finding.details]
    );
    if (result.rowCount) written++;
    else existing++;
  }

  const now = new Date().toLocaleString("en-PH", { timeZone: "Asia/Manila" });
  console.log(`\nIT 107 Monitoring Report  -  ${now} PHT`);
  console.log(`Scanned: ${scanned.rows[0].n} events (last 24 hours)\n`);
  if (findings.length === 0) console.log("No findings.");
  for (const finding of findings) console.log(finding.line);
  console.log(`\nNew flags written: ${written}     Already flagged today: ${existing}\n`);

  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
