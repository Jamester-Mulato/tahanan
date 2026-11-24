/**
 * Seeds the demo accounts the handout asks for:
 *   - one admin (created directly in the database, never through registration)
 *   - two normal users with known passwords
 *
 * Safe to re-run: it updates the documented password for the demo accounts and
 * leaves every other account untouched.
 *
 * Run: npx tsx scripts/seed-test-accounts.ts
 */
import { query, pool } from "../src/config/db";
import { hashPassword, verifyPassword } from "../src/utils/password";

interface DemoAccount {
  username: string;
  email: string;
  displayName: string;
  password: string;
  isAdmin: boolean;
  idNumber?: string;
}

const ACCOUNTS: DemoAccount[] = [
  {
    username: "tahananadmin",
    email: "jamestermulato+admin@gmail.com",
    displayName: "Tahanan Admin",
    password: "Admin#24100315",
    isAdmin: true
  },
  {
    username: "devicetest",
    email: "jamestermulato+device@gmail.com",
    displayName: "Device Test",
    password: "AppTest2026",
    isAdmin: false,
    idNumber: "2026-0001"
  },
  {
    username: "hand2372",
    email: "jamestermulato+h2372@gmail.com",
    displayName: "Hand Test",
    password: "Handout#2027",
    isAdmin: false,
    idNumber: "2027-2372"
  }
];

const ANSWERS: Array<[string, string]> = [
  ["Q6", "Bahay Kubo"],
  ["Q1", "Bantay"],
  ["Q3", "Mrs Cruz"]
];

async function upsertAccount(account: DemoAccount) {
  const existing = await query<{ id: string; password_hash: string | null }>(
    "SELECT id, password_hash FROM users WHERE lower(username) = lower($1)",
    [account.username]
  );

  const row = existing.rows[0];
  let id = row?.id;

  if (!id) {
    const inserted = await query<{ id: string }>(
      `INSERT INTO users
         (auth_provider, auth_provider_uid, email, display_name, username,
          password_hash, status, is_admin, id_number, email_verified_at,
          privacy_consent_at, password_changed_at)
       VALUES ('password', $2, $2, $3, $1, $4, 'active', $5, $6, now(), now(), now())
       RETURNING id`,
      [
        account.username,
        account.email,
        account.displayName,
        await hashPassword(account.password),
        account.isAdmin,
        account.idNumber ?? null
      ]
    );
    id = inserted.rows[0]!.id;
    console.log(`created ${account.username}`);
  } else {
    const matches = await verifyPassword(account.password, row?.password_hash);
    if (!matches) {
      await query(
        `UPDATE users
            SET password_hash = $2,
                is_admin = $3,
                status = 'active',
                email_verified_at = COALESCE(email_verified_at, now()),
                failed_login_count = 0,
                locked_until = NULL,
                updated_at = now()
          WHERE id = $1`,
        [id, await hashPassword(account.password), account.isAdmin]
      );
      console.log(`reset password for ${account.username}`);
    } else {
      await query("UPDATE users SET is_admin = $2 WHERE id = $1", [id, account.isAdmin]);
      console.log(`${account.username} already has the documented password`);
    }
  }

  for (const [question, answer] of ANSWERS) {
    await query(
      `INSERT INTO security_answers (user_id, question_key, answer_hash)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, question_key) DO NOTHING`,
      [id, question, await hashPassword(answer.toLowerCase())]
    );
  }

  return { ...account, id };
}

async function main() {
  console.log("Demo accounts (handout section 16):\n");
  for (const account of ACCOUNTS) {
    await upsertAccount(account);
    console.log(
      `  ${account.isAdmin ? "admin" : "user "}  ${account.username.padEnd(14)} ` +
        `${account.password.padEnd(16)} ${account.email}`
    );
  }

  const counts = await query<{ table: string; rows: number }>(
    `SELECT 'users' AS table, count(*)::int AS rows FROM users
     UNION ALL SELECT 'auth_events', count(*)::int FROM auth_events
     UNION ALL SELECT 'security_answers', count(*)::int FROM security_answers
     UNION ALL SELECT 'password_history', count(*)::int FROM password_history
     UNION ALL SELECT 'security_flags', count(*)::int FROM security_flags
     UNION ALL SELECT 'ip_blocks', count(*)::int FROM ip_blocks`
  );
  console.log("\nTable row counts:");
  for (const row of counts.rows) {
    console.log(`  ${row.table.padEnd(18)} ${row.rows}`);
  }

  console.log(
    "\nSecurity-question answers for all three: " +
      ANSWERS.map(([q, a]) => `${q}=${a}`).join(", ")
  );

  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exitCode = 1;
});
