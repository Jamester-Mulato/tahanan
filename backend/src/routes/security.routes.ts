import { Router } from "express";
import { query } from "../config/db";
import { requireAuth } from "../middleware/auth";
import { asyncRoute } from "../utils/async-route";
import type { AuthenticatedRequest } from "../types/auth";

export const securityRouter = Router();

/**
 * The signed-in account's own security trail. Every user (owner or tenant)
 * can see whether someone tried to access their account; events are limited
 * to entries that belong to them by id, email or the identifier typed at the
 * sign-in form.
 */
securityRouter.get(
  "/activity",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const user = req.authUser!;

    const me = await query<{ username: string | null; locked_until: string | null }>(
      "SELECT username, locked_until FROM users WHERE id = $1",
      [user.id]
    );
    const username = me.rows[0]?.username ?? "";
    const locked = Boolean(
      me.rows[0]?.locked_until &&
        new Date(me.rows[0].locked_until).getTime() > Date.now()
    );

    const summary = await query<{
      signins: number;
      failures: number;
      otp_failed: number;
      last_signin: string | null;
    }>(
      `SELECT
         count(*) FILTER (WHERE event_type IN ('LOGIN_SUCCESS','LOGIN_SUCCEEDED'))::int AS signins,
         count(*) FILTER (WHERE event_type = 'LOGIN_FAILED')::int AS failures,
         count(*) FILTER (WHERE event_type = 'OTP_FAILED')::int AS otp_failed,
         max(created_at) FILTER (WHERE event_type IN ('LOGIN_SUCCESS','LOGIN_SUCCEEDED')) AS last_signin
       FROM auth_events
      WHERE created_at > now() - interval '30 days'
        AND (
          user_id = $1
          OR lower(email) = lower($2)
          OR ($3 <> '' AND lower(username_typed) = lower($3))
        )`,
      [user.id, user.email, username]
    );

    const events = await query(
      `SELECT id, event_type, COALESCE(username_typed, email) AS identifier,
              ip_address, user_agent, details, created_at
         FROM auth_events
        WHERE user_id = $1
           OR lower(email) = lower($2)
           OR ($3 <> '' AND lower(username_typed) = lower($3))
        ORDER BY created_at DESC
        LIMIT 100`,
      [user.id, user.email, username]
    );

    res.json({
      account: { username, email: user.email, locked },
      summary: summary.rows[0],
      events: events.rows
    });
  })
);
