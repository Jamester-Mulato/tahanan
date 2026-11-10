import { env } from "../config/env";
import { query } from "../config/db";

const WINDOW_MS = 10 * 60 * 1000;
const failures = new Map<string, number[]>();
const blockedUntil = new Map<string, number>();

function now() {
  return Date.now();
}

function prune(ip: string): number[] {
  const cutoff = now() - WINDOW_MS;
  const recent = (failures.get(ip) ?? []).filter((time) => time > cutoff);
  if (recent.length === 0) failures.delete(ip);
  else failures.set(ip, recent);
  return recent;
}

/**
 * Seconds still blocked for this IP, or 0. The in-memory map answers instantly;
 * `ip_blocks` is the durable copy so a restart, or a second process, cannot
 * forget a block (protection 5 / handout 12).
 */
export async function ipBlockSeconds(ip: string | undefined): Promise<number> {
  if (!ip) return 0;

  const until = blockedUntil.get(ip);
  if (until) {
    const remaining = Math.ceil((until - now()) / 1000);
    if (remaining > 0) return remaining;
    blockedUntil.delete(ip);
  }

  const stored = await query<{ seconds: number }>(
    `SELECT GREATEST(ceil(extract(epoch FROM (blocked_until - now()))), 0)::int AS seconds
       FROM ip_blocks
      WHERE ip_address = $1
        AND blocked_until > now()
      ORDER BY blocked_until DESC
      LIMIT 1`,
    [ip]
  );

  const seconds = stored.rows[0]?.seconds ?? 0;
  if (seconds > 0) blockedUntil.set(ip, now() + seconds * 1000);
  return seconds;
}

/**
 * Records one failed attempt. Returns the block duration when this attempt
 * crosses the threshold, otherwise 0. The block is persisted to `ip_blocks`.
 */
export async function recordIpFailure(ip: string | undefined): Promise<number> {
  if (!ip) return 0;

  const recent = prune(ip);
  recent.push(now());
  failures.set(ip, recent);

  if (recent.length >= env.IP_BLOCK_THRESHOLD) {
    blockedUntil.set(ip, now() + env.IP_BLOCK_SECONDS * 1000);
    failures.delete(ip);

    await query(
      `INSERT INTO ip_blocks (ip_address, blocked_until, reason)
       VALUES ($1, now() + ($2 || ' seconds')::interval, $3)
       ON CONFLICT (ip_address) DO UPDATE
         SET blocked_until = EXCLUDED.blocked_until,
             reason = EXCLUDED.reason`,
      [
        ip,
        String(env.IP_BLOCK_SECONDS),
        `${recent.length} failures in 10 minutes`
      ]
    );

    return env.IP_BLOCK_SECONDS;
  }

  return 0;
}

/** A successful sign-in clears the failure window and lifts the block. */
export async function clearIpFailures(ip: string | undefined): Promise<void> {
  if (!ip) return;
  failures.delete(ip);
  blockedUntil.delete(ip);
  await query("DELETE FROM ip_blocks WHERE ip_address = $1", [ip]);
}
