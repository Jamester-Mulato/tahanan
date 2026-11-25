import { env } from "../config/env";
import { query } from "../config/db";

export interface SessionSettings {
  idleTimeoutSeconds: number;
  warningSeconds: number;
}

let cached: { at: number; value: SessionSettings } | null = null;
const CACHE_MS = 5000;

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function fallback(): SessionSettings {
  const idle = clamp(env.IDLE_TIMEOUT_SECONDS, 5, 3600);
  return { idleTimeoutSeconds: idle, warningSeconds: Math.min(60, idle) };
}

/**
 * Idle-session policy, editable at runtime through the admin console.
 *
 * Stored in app_settings (seed values come from the environment on first
 * boot). A 5-second cache keeps the per-request cost negligible; the admin
 * endpoint invalidates it immediately.
 */
export async function sessionSettings(): Promise<SessionSettings> {
  if (cached && Date.now() - cached.at < CACHE_MS) return cached.value;

  try {
    const rows = await query<{ key: string; value: string }>(
      `SELECT key, value FROM app_settings
        WHERE key IN ('idle_timeout_seconds', 'session_warning_seconds')`
    );
    const map = new Map(rows.rows.map((row) => [row.key, row.value]));
    const idle = clamp(
      Number(map.get("idle_timeout_seconds") ?? env.IDLE_TIMEOUT_SECONDS),
      5,
      3600
    );
    const warning = clamp(
      Number(map.get("session_warning_seconds") ?? Math.min(60, idle)),
      0,
      idle
    );
    const value = { idleTimeoutSeconds: idle, warningSeconds: warning };
    cached = { at: Date.now(), value };
    return value;
  } catch {
    return fallback();
  }
}

export function invalidateSessionSettings(): void {
  cached = null;
}

export async function saveSessionSettings(
  input: SessionSettings
): Promise<SessionSettings> {
  const idle = clamp(Math.round(input.idleTimeoutSeconds), 5, 3600);
  const warning = clamp(Math.round(input.warningSeconds), 0, idle);

  await query(
    `INSERT INTO app_settings (key, value, updated_at)
     VALUES ('idle_timeout_seconds', $1, now()),
            ('session_warning_seconds', $2, now())
     ON CONFLICT (key) DO UPDATE
       SET value = EXCLUDED.value, updated_at = now()`,
    [String(idle), String(warning)]
  );
  invalidateSessionSettings();
  return { idleTimeoutSeconds: idle, warningSeconds: warning };
}
