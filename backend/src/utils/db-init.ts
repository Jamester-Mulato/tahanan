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

/**
 * The ordered schema pipeline. `001` is the structural base and is verified
 * strictly; the ones after it are written to be idempotent, so a changed file
 * is re-applied once and re-recorded. Nothing is applied on a plain restart.
 */
const MANIFEST = [
  "008_baseline_handout.sql",
  "009_admin_console.sql",
  "010_runtime_settings.sql",
  "011_auth_tables.sql"
] as const;

function checksumOf(sql: string): string {
  return crypto.createHash("sha256").update(sql, "utf8").digest("hex");
}

async function applyBaseSchema(
  db: pg.Pool,
  schema: string,
  expectedChecksum: string
) {
  const table = await db.query(
    "SELECT to_regclass('public.schema_migrations') AS name"
  );

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
    return;
  }

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

async function applyManifest(db: pg.Pool) {
  for (const file of MANIFEST) {
    const version = file.slice(0, 3);
    const sql = await fs.readFile(
      path.resolve(process.cwd(), "sql", file),
      "utf8"
    );
    const checksum = checksumOf(sql);

    const applied = await db.query<{ checksum: string }>(
      "SELECT checksum FROM schema_migrations WHERE version = $1",
      [version]
    );

    if (!applied.rows[0]) {
      if (!env.DB_AUTO_INIT_SCHEMA) {
        throw new Error(
          `Migration ${file} has not been applied and DB_AUTO_INIT_SCHEMA=false.`
        );
      }
      await db.query(sql);
      await db.query(
        `INSERT INTO schema_migrations(version, checksum)
         VALUES ($1, $2)
         ON CONFLICT(version) DO UPDATE SET checksum = EXCLUDED.checksum`,
        [version, checksum]
      );
      console.log(`[DB] applied ${file}`);
      continue;
    }

    if (applied.rows[0].checksum === checksum) continue;

    // These files are idempotent by contract, so the safe reaction to an edit
    // is to apply it once more rather than refuse to boot.
    console.warn(`[DB] ${file} changed since it was applied; re-applying`);
    await db.query(sql);
    await db.query(
      "UPDATE schema_migrations SET checksum = $2 WHERE version = $1",
      [version, checksum]
    );
  }
}

async function initializeOrVerifySchema(
  schema: string,
  expectedChecksum: string
) {
  const db = createPool();
  try {
    await applyBaseSchema(db, schema, expectedChecksum);
    await applyManifest(db);

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
  const expectedChecksum = crypto
    .createHash("sha256")
    .update(schema, "utf8")
    .digest("hex");

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
