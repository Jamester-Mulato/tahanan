import pg, { type QueryResultRow } from "pg";
import { env } from "./env";

const { Pool } = pg;

export function createPool(database = env.DATABASE_NAME) {
  const useUrl = Boolean(env.DATABASE_URL);
  const sslEnabled = env.DATABASE_SSL ?? useUrl;

  return new Pool({
    ...(useUrl
      ? { connectionString: env.DATABASE_URL }
      : {
          host: env.DATABASE_HOST,
          port: env.DATABASE_PORT,
          database,
          user: env.DATABASE_USER,
          password: env.DATABASE_PASSWORD
        }),
    ...(sslEnabled ? { ssl: { rejectUnauthorized: false } } : {}),
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000
  });
}

export const pool = createPool();

export async function query<T extends QueryResultRow = any>(
  text: string,
  values: unknown[] = []
) {
  return pool.query<T>(text, values);
}

