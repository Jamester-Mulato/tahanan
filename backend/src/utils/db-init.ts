import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import pg from "pg";
import { env } from "../config/env";
import { createPool, pool } from "../config/db";

function quoteIdentifier(value: string): string {
  if (!/^[A-Za-z_][A-Za-z0-9_$]*$/.test(value)) throw new Error("Unsafe database name");
  return `"${value}"`;
}

async function ensureDatabaseExists() {
  const admin = new pg.Pool({
    host: env.DATABASE_HOST,
    port: env.DATABASE_PORT,
    database: env.DATABASE_ADMIN_DATABASE,
    user: env.DATABASE_USER,
    password: env.DATABASE_PASSWORD,
    max: 1
  });
  try {
    const result = await admin.query("SELECT 1 FROM pg_database WHERE datname = $1", [env.DATABASE_NAME]);
    if (result.rowCount === 0) {
      if (!env.DB_AUTO_CREATE) {
        throw new Error(`Database ${env.DATABASE_NAME} does not exist and DB_AUTO_CREATE=false.`);
      }
      await admin.query(`CREATE DATABASE ${quoteIdentifier(env.DATABASE_NAME)}`);
      console.log(`[DB] created database ${env.DATABASE_NAME}`);
    }
  } finally {
    await admin.end();
  }
}

async function initializeOrVerifySchema(schema: string, expectedChecksum: string) {
  const db = createPool();
  try {
    const table = await db.query("SELECT to_regclass('public.schema_migrations') AS name");

    if (!table.rows[0]?.name) {
      if (!env.DB_AUTO_INIT_SCHEMA) {
        throw new Error("Schema is missing and DB_AUTO_INIT_SCHEMA=false.");
      }
      console.log("[DB] schema missing; applying bundled schema");
      await db.query(schema);
      await db.query(
        `INSERT INTO schema_migrations(version, checksum)
         VALUES ('001', $1)
         ON CONFLICT(version) DO UPDATE SET checksum = EXCLUDED.checksum`,
        [expectedChecksum]
      );
      console.log("[DB] schema installed");
    } else {
      const row = await db.query(
        "SELECT checksum FROM schema_migrations WHERE version = '001'"
      );
      if (!row.rows[0]) {
        throw new Error(
          "schema_migrations exists but migration 001 is missing. Refusing to guess."
        );
      }

      if (env.DB_VERIFY_SCHEMA && row.rows[0].checksum !== expectedChecksum) {
        throw new Error(
          "DATABASE_SCHEMA_MISMATCH: PostgreSQL schema checksum differs from bundled Tahanan schema. No data was changed."
        );
      }

      console.log("[DB] schema verified: MATCH");
    }

    // 001 is the original base schema; everything the handout added (username,
    // password hash, ID fields, OTP, security answers, IP blocks, idle column,
    // activity-log columns, concern statuses) lives in this idempotent
    // baseline. Running it here means a brand-new database (Neon, a fresh
    // local install) gets the complete current schema, not just upgrades.
    const baseline = await fs.readFile(
      path.resolve(process.cwd(), "sql/008_baseline_handout.sql"),
      "utf8"
    );
    await db.query(baseline);
    console.log("[DB] handout baseline ensured");

    const adminConsole = await fs.readFile(
      path.resolve(process.cwd(), "sql/009_admin_console.sql"),
      "utf8"
    );
    await db.query(adminConsole);
    console.log("[DB] admin console schema ensured");

    const runtimeSettings = await fs.readFile(
      path.resolve(process.cwd(), "sql", "010_runtime_settings.sql"),
      "utf8"
    );
    await db.query(runtimeSettings);
    const initialIdle = Math.min(Math.max(env.IDLE_TIMEOUT_SECONDS, 5), 3600);
    await db.query(
      `INSERT INTO app_settings (key, value)
       VALUES ('idle_timeout_seconds', $1), ('session_warning_seconds', $2)
       ON CONFLICT (key) DO NOTHING`,
      [String(initialIdle), String(Math.min(60, initialIdle))]
    );
    console.log("[DB] runtime settings ensured");
  } finally {
    await db.end();
  }
}

export async function initializeDatabase() {
  const schemaPath = path.resolve(process.cwd(), "sql/001_schema.sql");
  const schema = await fs.readFile(schemaPath, "utf8");
  const expectedChecksum = crypto.createHash("sha256").update(schema, "utf8").digest("hex");

  // Neon (and most managed Postgres) creates the database up front and does
  // not let the app role create databases or reach the "postgres" admin
  // database. With DATABASE_URL we connect straight to that database.
  if (!env.DATABASE_URL) {
    await ensureDatabaseExists();
  }
  await initializeOrVerifySchema(schema, expectedChecksum);
}

if (process.argv.includes("--verify-only")) {
  initializeDatabase()
    .then(() => pool.end())
    .catch(async (error) => {
      console.error(error);
      await pool.end();
      process.exit(1);
    });
}
