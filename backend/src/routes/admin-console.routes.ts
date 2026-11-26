import fs from "node:fs/promises";
import path from "node:path";
import { Router } from "express";
import { z } from "zod";
import { pool, query } from "../config/db";
import { requireAuth } from "../middleware/auth";
import { requireAdmin } from "../middleware/require-admin";
import { asyncRoute } from "../utils/async-route";
import { HttpError } from "../utils/http-error";
import {
  deleteAccount,
  logoutAllSessions
} from "../services/admin-operations.service";
import {
  saveSessionSettings,
  sessionSettings
} from "../services/settings.service";
import type { AuthenticatedRequest } from "../types/auth";

export const adminConsoleRouter = Router();

adminConsoleRouter.use(requireAuth, requireAdmin);

const uuid = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);

async function audit(
  req: AuthenticatedRequest,
  action: string,
  target?: string | null,
  details?: unknown
): Promise<void> {
  await query(
    `INSERT INTO admin_audit (admin_user_id, action, target, details, ip_address)
     VALUES ($1, $2, $3, $4, $5)`,
    [
      req.authUser?.id ?? null,
      action,
      target ?? null,
      details === undefined ? null : details,
      req.ip ?? null
    ]
  );
}

// ---------------------------------------------------------------
// OVERVIEW
// ---------------------------------------------------------------
adminConsoleRouter.get(
  "/overview",
  asyncRoute(async (_req, res) => {
    const counts = await query(
      `SELECT
         (SELECT count(*) FROM users)::int AS users,
         (SELECT count(*) FROM users WHERE is_admin)::int AS admins,
         (SELECT count(*) FROM users WHERE status <> 'active')::int AS inactive_users,
         (SELECT count(*) FROM boarding_houses)::int AS houses,
         (SELECT count(*) FROM rooms)::int AS rooms,
         (SELECT count(*) FROM tenants)::int AS tenants,
         (SELECT count(*) FROM announcements)::int AS announcements,
         (SELECT count(*) FROM concerns)::int AS concerns,
         (SELECT count(*) FROM client_error_logs)::int AS client_errors,
         (SELECT count(*) FROM client_error_logs WHERE created_at > now() - interval '24 hours')::int AS client_errors_24h,
         (SELECT count(*) FROM auth_events)::int AS auth_events,
         pg_size_pretty(pg_database_size(current_database())) AS db_size`
    );

    const version = await query<{ version: string }>("SELECT version()");

    res.json({
      ...counts.rows[0],
      database: version.rows[0]?.version ?? "",
      uptimeSeconds: Math.round(process.uptime()),
      node: process.version,
      environment: process.env.NODE_ENV ?? "development"
    });
  })
);

// ---------------------------------------------------------------
// SESSION POLICY (runtime; clients pick it up on the next page load)
// ---------------------------------------------------------------
adminConsoleRouter.get(
  "/session",
  asyncRoute(async (_req, res) => {
    res.json(await sessionSettings());
  })
);

adminConsoleRouter.post(
  "/session",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z
      .object({
        idleTimeoutSeconds: z.number().int().min(5).max(3600),
        warningSeconds: z.number().int().min(0).max(3600)
      })
      .parse(req.body);
    const saved = await saveSessionSettings(body);
    await audit(req, "UPDATE_SESSION_POLICY", null, saved);
    res.json(saved);
  })
);

// ---------------------------------------------------------------
// DATABASE BROWSER
// ---------------------------------------------------------------

adminConsoleRouter.get(
  "/tables",
  asyncRoute(async (_req, res) => {
    const tables = await query<{ name: string; estimated_rows: number }>(
      `SELECT c.relname AS name, GREATEST(c.reltuples, 0)::bigint AS estimated_rows
         FROM pg_class c
         JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relkind = 'r'
        ORDER BY c.relname`
    );
    res.json({ tables: tables.rows });
  })
);

adminConsoleRouter.get(
  "/tables/:table",
  asyncRoute(async (req, res) => {
    const table = String(req.params.table);
    const exists = await query(
      "SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = $1",
      [table]
    );
    if (!exists.rowCount) throw new HttpError(404, "TABLE_NOT_FOUND", "Unknown table.");

    const limit = Math.min(Math.max(Number(req.query.limit ?? 100) || 100, 1), 500);
    const offset = Math.max(Number(req.query.offset ?? 0) || 0, 0);
    const quoted = `"${table.replaceAll('"', '""')}"`;

    const columns = await query(
      `SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = $1
        ORDER BY ordinal_position`,
      [table]
    );
    const rows = await query(
      `SELECT * FROM ${quoted} LIMIT $1 OFFSET $2`,
      [limit, offset]
    );
    const total = await query(`SELECT count(*)::int AS n FROM ${quoted}`);

    res.json({
      table,
      columns: columns.rows,
      rows: rows.rows,
      total: total.rows[0]?.n ?? 0,
      limit,
      offset
    });
  })
);

adminConsoleRouter.post(
  "/sql",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const body = z
      .object({ sql: z.string().trim().min(1).max(200000) })
      .parse(req.body);

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SET LOCAL statement_timeout = 15000");
      const result = await client.query(body.sql);
      await client.query("COMMIT");

      const last = Array.isArray(result) ? result[result.length - 1] : result;
      const rows = Array.isArray(last.rows) ? last.rows.slice(0, 500) : [];
      const columns = Array.isArray(last.fields)
        ? last.fields.map((field: { name: string }) => field.name)
        : [];

      await audit(req, "SQL", null, {
        sql: body.sql.slice(0, 4000),
        command: last.command,
        rowCount: last.rowCount
      });

      res.json({
        command: last.command ?? "OK",
        rowCount: last.rowCount ?? 0,
        columns,
        rows,
        truncated: (last.rowCount ?? 0) > rows.length && rows.length === 500
      });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      const message =
        error instanceof Error ? error.message : "The statement failed.";
      await audit(req, "SQL_FAILED", null, {
        sql: body.sql.slice(0, 4000),
        error: message.slice(0, 500)
      });
      res.status(400).json({ error: "SQL_ERROR", message });
    } finally {
      client.release();
    }
  })
);

// ---------------------------------------------------------------
// LOGS
// ---------------------------------------------------------------
adminConsoleRouter.get(
  "/error-log",
  asyncRoute(async (req, res) => {
    const lines = Math.min(Math.max(Number(req.query.lines ?? 200) || 200, 1), 500);
    const file = path.resolve(process.cwd(), "logs", "error.log");
    let text = "";
    try {
      text = await fs.readFile(file, "utf8");
    } catch {
      text = "";
    }
    const tail = text.trim() ? text.trim().split(/\r?\n/).slice(-lines) : [];
    res.json({ lines: tail });
  })
);

adminConsoleRouter.get(
  "/client-errors",
  asyncRoute(async (req, res) => {
    const limit = Math.min(Math.max(Number(req.query.limit ?? 100) || 100, 1), 500);
    const offset = Math.max(Number(req.query.offset ?? 0) || 0, 0);
    const username = String(req.query.username ?? "");

    const rows = await query(
      `SELECT id, username, platform, app_version, message, stack, screen,
              extra, ip_address, created_at
         FROM client_error_logs
        WHERE ($1 = '' OR username ILIKE '%' || $1 || '%')
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3`,
      [username, limit, offset]
    );
    const total = await query(
      `SELECT count(*)::int AS n FROM client_error_logs
        WHERE ($1 = '' OR username ILIKE '%' || $1 || '%')`,
      [username]
    );

    res.json({ errors: rows.rows, total: total.rows[0]?.n ?? 0 });
  })
);

adminConsoleRouter.delete(
  "/client-errors",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const cleared = await query("DELETE FROM client_error_logs");
    await audit(req, "CLEAR_CLIENT_ERRORS", null, { removed: cleared.rowCount });
    res.json({ ok: true, removed: cleared.rowCount ?? 0 });
  })
);

adminConsoleRouter.get(
  "/audit",
  asyncRoute(async (_req, res) => {
    const rows = await query(
      `SELECT a.id, a.action, a.target, a.details, a.ip_address, a.created_at,
              u.username
         FROM admin_audit a
         LEFT JOIN users u ON u.id = a.admin_user_id
        ORDER BY a.created_at DESC
        LIMIT 200`
    );
    res.json({ entries: rows.rows });
  })
);

// ---------------------------------------------------------------
// USERS
// ---------------------------------------------------------------
adminConsoleRouter.get(
  "/users",
  asyncRoute(async (_req, res) => {
    const rows = await query(
      `SELECT u.id, u.username, u.email, u.display_name, u.status, u.is_admin,
              u.created_at, u.last_login_at,
              (SELECT count(*) FROM boarding_houses bh WHERE bh.owner_user_id = u.id)::int AS owned_houses,
              (SELECT count(*) FROM boarding_house_memberships m
                WHERE m.user_id = u.id AND m.status = 'active')::int AS memberships
         FROM users u
        ORDER BY u.created_at`
    );
    res.json({ users: rows.rows });
  })
);

adminConsoleRouter.patch(
  "/users/:id",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const id = uuid.parse(req.params.id);
    const body = z
      .object({
        status: z.enum(["active", "pending", "disabled"]).optional(),
        is_admin: z.boolean().optional()
      })
      .parse(req.body);

    if (!body.status && body.is_admin === undefined) {
      throw new HttpError(400, "NOTHING_TO_UPDATE", "Provide status or is_admin.");
    }
    if (id === req.authUser!.id) {
      if (body.is_admin === false || (body.status && body.status !== "active")) {
        throw new HttpError(
          400,
          "SELF_LOCKOUT",
          "You cannot remove your own access."
        );
      }
    }

    const sets: string[] = [];
    const values: unknown[] = [];
    let index = 1;
    if (body.status) {
      sets.push(`status = $${index++}`);
      values.push(body.status);
    }
    if (body.is_admin !== undefined) {
      sets.push(`is_admin = $${index++}`);
      values.push(body.is_admin);
    }
    sets.push("token_version = token_version + 1");
    values.push(id);

    const updated = await query(
      `UPDATE users SET ${sets.join(", ")} WHERE id = $${index}
       RETURNING id, username, status, is_admin`,
      values
    );
    if (!updated.rowCount) throw new HttpError(404, "USER_NOT_FOUND", "Unknown user.");

    if (body.status && body.status !== "active") {
      await query("DELETE FROM auth_refresh_tokens WHERE user_id = $1", [id]);
    }

    await audit(req, "UPDATE_USER", id, body);
    res.json({ user: updated.rows[0] });
  })
);

adminConsoleRouter.post(
  "/users/:id/logout-all",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const id = uuid.parse(req.params.id);
    const sessions = await logoutAllSessions(id, req);
    await audit(req, "LOGOUT_ALL", id, { sessions });
    res.json({ ok: true, sessions });
  })
);

adminConsoleRouter.delete(
  "/users/:id",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const id = uuid.parse(req.params.id);
    const removed = await deleteAccount({
      userId: id,
      actorId: req.authUser!.id
    });
    await audit(req, "DELETE_USER", id, removed);
    res.json({ ok: true, removed });
  })
);

// ---------------------------------------------------------------
// SESSIONS / BLOCKS
// ---------------------------------------------------------------
adminConsoleRouter.get(
  "/sessions",
  asyncRoute(async (_req, res) => {
    const rows = await query(
      `SELECT t.id, t.user_id, u.username, t.device_name, t.ip_address,
              t.created_at, t.last_used_at, t.expires_at, t.revoked_at
         FROM auth_refresh_tokens t
         LEFT JOIN users u ON u.id = t.user_id
        ORDER BY t.created_at DESC
        LIMIT 200`
    );
    res.json({ sessions: rows.rows });
  })
);

adminConsoleRouter.delete(
  "/sessions/:id",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const id = uuid.parse(req.params.id);
    const revoked = await query(
      "UPDATE auth_refresh_tokens SET revoked_at = now() WHERE id = $1 RETURNING user_id",
      [id]
    );
    if (!revoked.rowCount) throw new HttpError(404, "SESSION_NOT_FOUND", "Unknown session.");
    await audit(req, "REVOKE_SESSION", id, { userId: revoked.rows[0].user_id });
    res.json({ ok: true });
  })
);

adminConsoleRouter.get(
  "/ip-blocks",
  asyncRoute(async (_req, res) => {
    const rows = await query(
      `SELECT ip_address, blocked_until, reason, created_at
         FROM ip_blocks ORDER BY blocked_until DESC LIMIT 200`
    );
    res.json({ blocks: rows.rows });
  })
);

adminConsoleRouter.delete(
  "/ip-blocks",
  asyncRoute(async (req: AuthenticatedRequest, res) => {
    const ip = String(req.query.ip ?? "");
    const removed = ip
      ? await query("DELETE FROM ip_blocks WHERE ip_address = $1", [ip])
      : await query("DELETE FROM ip_blocks");
    await audit(req, "CLEAR_IP_BLOCKS", ip || null, { removed: removed.rowCount });
    res.json({ ok: true, removed: removed.rowCount ?? 0 });
  })
);
