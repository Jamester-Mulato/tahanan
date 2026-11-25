import { Router } from "express";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { query } from "../config/db";
import { env } from "../config/env";
import { asyncRoute } from "../utils/async-route";

export const clientErrorsRouter = Router();

/** Best-effort in-memory limiter: 30 reports per minute per IP. */
const hits = new Map<string, number[]>();

function allowed(ip: string): boolean {
  const now = Date.now();
  const recent = (hits.get(ip) ?? []).filter((time) => now - time < 60_000);
  if (recent.length >= 30) {
    hits.set(ip, recent);
    return false;
  }
  recent.push(now);
  hits.set(ip, recent);

  if (hits.size > 2000) {
    for (const [key, times] of hits) {
      if (times.every((time) => now - time > 60_000)) hits.delete(key);
    }
  }
  return true;
}

clientErrorsRouter.post(
  "/",
  asyncRoute(async (req, res) => {
    const ip = req.ip ?? "unknown";
    if (!allowed(ip)) {
      res.status(429).json({ ok: false });
      return;
    }

    const body = z
      .object({
        message: z.string().trim().min(1).max(2000),
        stack: z.string().max(12000).optional(),
        screen: z.string().max(120).optional(),
        platform: z.string().max(40).optional(),
        appVersion: z.string().max(40).optional(),
        extra: z.record(z.string(), z.any()).optional()
      })
      .parse(req.body);

    // A valid bearer token attaches the report to an account; missing or
    // stale tokens are fine, the report is kept anonymously.
    let userId: string | null = null;
    let username: string | null = null;
    const header = req.header("authorization");
    if (header?.startsWith("Bearer ")) {
      try {
        const payload = jwt.verify(header.slice(7), env.JWT_SECRET) as jwt.JwtPayload;
        if (payload.sub) {
          const user = await query<{ id: string; username: string | null }>(
            "SELECT id, username FROM users WHERE id = $1",
            [payload.sub]
          );
          if (user.rows[0]) {
            userId = user.rows[0].id;
            username = user.rows[0].username;
          }
        }
      } catch {
        // keep it anonymous
      }
    }

    await query(
      `INSERT INTO client_error_logs
         (user_id, username, platform, app_version, message, stack, screen,
          extra, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        userId,
        username,
        body.platform ?? null,
        body.appVersion ?? null,
        body.message,
        body.stack ?? null,
        body.screen ?? null,
        body.extra ?? null,
        ip,
        req.get("user-agent") ?? null
      ]
    );

    res.status(202).json({ ok: true });
  })
);
