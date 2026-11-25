import type { NextFunction, Response } from "express";
import { query } from "../config/db";
import { logAuthEvent } from "../services/auth-events.service";
import type { AuthenticatedRequest } from "../types/auth";

/**
 * Runs after requireAuth. Only users with users.is_admin may reach the admin
 * console; every refusal is written to the append-only auth log.
 */
export async function requireAdmin(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  const result = await query<{ is_admin: boolean }>(
    "SELECT is_admin FROM users WHERE id = $1",
    [req.authUser!.id]
  );

  if (!result.rows[0]?.is_admin) {
    await logAuthEvent({
      eventType: "ADMIN_ACCESS_DENIED",
      userId: req.authUser!.id,
      email: req.authUser!.email,
      req,
      details: { path: req.originalUrl, method: req.method }
    });
    res.status(403).json({
      error: "ACCESS_DENIED",
      message: "Access denied."
    });
    return;
  }

  next();
}
