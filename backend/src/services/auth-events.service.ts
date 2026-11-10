import type { Request } from "express";
import { query } from "../config/db";

export interface AuthEventInput {
  eventType: string;
  userId?: string | null;
  email?: string | null;
  /** The identifier exactly as the visitor typed it (never normalized). */
  usernameTyped?: string | null;
  req?: Request;
  details?: Record<string, unknown>;
}

/**
 * Append-only audit trail for authentication decisions. Never throws: a
 * logging failure must not break a login.
 */
export async function logAuthEvent(input: AuthEventInput): Promise<void> {
  try {
    await query(
      `INSERT INTO auth_events
         (event_type, user_id, email, username_typed, ip_address, user_agent, details)
       VALUES ($1, $2, lower($3), $4, $5, $6, $7::jsonb)`,
      [
        input.eventType,
        input.userId ?? null,
        input.email ?? null,
        input.usernameTyped ?? input.email ?? null,
        input.req?.ip ?? null,
        input.req?.get("user-agent") ?? null,
        input.details ? JSON.stringify(input.details) : null
      ]
    );
  } catch (error) {
    console.error(
      "[auth-event]",
      input.eventType,
      error instanceof Error ? error.message : "unknown error"
    );
  }
}
