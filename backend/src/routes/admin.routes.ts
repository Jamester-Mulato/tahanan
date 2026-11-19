import { Router } from "express";
import { query } from "../config/db";
import { requireAuth } from "../middleware/auth";
import { logAuthEvent } from "../services/auth-events.service";
import { asyncRoute } from "../utils/async-route";
import type { AuthenticatedRequest } from "../types/auth";

export const adminRouter = Router();

adminRouter.get(
  "/security",
  requireAuth,
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const admin = await query<{ is_admin: boolean }>(
      "SELECT is_admin FROM users WHERE id = $1",
      [req.authUser!.id]
    );

    if (!admin.rows[0]?.is_admin) {
      await logAuthEvent({
        eventType: "ADMIN_ACCESS_DENIED",
        userId: req.authUser!.id,
        email: req.authUser!.email,
        req,
        details: { path: "/api/admin/security" }
      });
      res.status(403).json({
        error: "ACCESS_DENIED",
        message: "Access denied."
      });
      return;
    }

    if (req.query.log !== "0") {
      await logAuthEvent({
        eventType: "ADMIN_VIEWED_DASHBOARD",
        userId: req.authUser!.id,
        email: req.authUser!.email,
        req
      });
    }

    const summary = await query<{
      logins: number;
      failed: number;
      locked: number;
      blocked: number;
      otp_sent: number;
      otp_failed: number;
      alerts: number;
    }>(
      `SELECT
         count(*) FILTER (WHERE event_type IN ('LOGIN_SUCCESS','LOGIN_SUCCEEDED'))::int AS logins,
         count(*) FILTER (WHERE event_type = 'LOGIN_FAILED')::int AS failed,
         (SELECT count(*)::int FROM users WHERE locked_until > now()) AS locked,
         (SELECT count(*)::int FROM ip_blocks WHERE blocked_until > now()) AS blocked,
         count(*) FILTER (WHERE event_type = 'OTP_SENT')::int AS otp_sent,
         count(*) FILTER (WHERE event_type = 'OTP_FAILED')::int AS otp_failed,
         count(*) FILTER (WHERE event_type = 'ALERT_EMAIL_SENT')::int AS alerts
       FROM auth_events
      WHERE created_at >= date_trunc('day', now())`
    );

    const hourly = await query<{ hour: string; failures: number }>(
      `SELECT to_char(date_trunc('hour', created_at), 'HH24:00') AS hour,
              count(*)::int AS failures
         FROM auth_events
        WHERE event_type = 'LOGIN_FAILED'
          AND created_at > now() - interval '24 hours'
        GROUP BY 1
        ORDER BY 1`
    );

    const topIps = await query<{ ip_address: string; failures: number; blocked: boolean }>(
      `SELECT ip_address,
              count(*)::int AS failures,
              EXISTS (
                SELECT 1 FROM ip_blocks b
                 WHERE b.ip_address = e.ip_address AND b.blocked_until > now()
              ) AS blocked
         FROM auth_events e
        WHERE event_type = 'LOGIN_FAILED'
          AND created_at > now() - interval '24 hours'
          AND ip_address IS NOT NULL
        GROUP BY ip_address
        ORDER BY failures DESC
        LIMIT 5`
    );

    const flags = await query(
      `SELECT pattern, target, severity, details, flag_date
         FROM security_flags
        WHERE flag_date = CURRENT_DATE
        ORDER BY id DESC
        LIMIT 20`
    );

    const filters = {
      from: String(req.query.from ?? ""),
      to: String(req.query.to ?? ""),
      event: String(req.query.event ?? ""),
      username: String(req.query.username ?? ""),
      ip: String(req.query.ip ?? "")
    };

    const events = await query(
      `SELECT id, event_type, COALESCE(username_typed, email) AS username,
              ip_address, user_agent, details, created_at
         FROM auth_events
        WHERE ($1 = '' OR created_at >= $1::date)
          AND ($2 = '' OR created_at < ($2::date + interval '1 day'))
          AND ($3 = '' OR event_type = $3)
          AND ($4 = '' OR COALESCE(username_typed, email) ILIKE '%' || $4 || '%')
          AND ($5 = '' OR ip_address = $5)
        ORDER BY created_at DESC
        LIMIT 50`,
      [filters.from, filters.to, filters.event, filters.username, filters.ip]
    );

    res.json({
      summary: summary.rows[0],
      hourly: hourly.rows,
      topIps: topIps.rows,
      flags: flags.rows,
      events: events.rows,
      filters
    });
  })
);
