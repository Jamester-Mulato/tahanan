import type { NextFunction, Response } from "express";
import jwt from "jsonwebtoken";
import type { AuthenticatedRequest, AuthUser } from "../types/auth";
import { env } from "../config/env";
import { query } from "../config/db";

interface AccessTokenPayload extends jwt.JwtPayload {
  sub: string;
  email: string;
  displayName: string;
  tv?: number;
}

/**
 * Verifies the JWT and also checks the account's token version. Bumping the
 * version (logout-all, password change, admin disable) invalidates every
 * access token already issued.
 */
export async function requireAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  const header = req.header("authorization");

  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({
      error: "UNAUTHENTICATED",
      message: "Bearer access token is required."
    });
    return;
  }

  const token = header.slice("Bearer ".length);

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as AccessTokenPayload;

    if (!payload.sub || !payload.email || typeof payload.tv !== "number") {
      res.status(401).json({
        error: "INVALID_TOKEN",
        message: "Access token payload is invalid."
      });
      return;
    }

    const result = await query<{
      token_version: number;
      status: string;
      is_admin: boolean;
      last_activity_at: string | null;
    }>(
      "SELECT token_version, status, is_admin, last_activity_at FROM users WHERE id = $1",
      [payload.sub]
    );
    const row = result.rows[0];

    if (
      !row ||
      row.status !== "active" ||
      row.token_version !== payload.tv
    ) {
      res.status(401).json({
        error: "INVALID_TOKEN",
        message: "Access token is no longer valid. Please sign in again."
      });
      return;
    }

    if (
      row.last_activity_at &&
      Date.now() - new Date(row.last_activity_at).getTime() >
        env.IDLE_TIMEOUT_SECONDS * 1000
    ) {
      res.status(401).json({
        error: "SESSION_IDLE",
        message: "Your session expired after inactivity. Please sign in again."
      });
      return;
    }

    await query("UPDATE users SET last_activity_at = now() WHERE id = $1", [
      payload.sub
    ]);

    const user: AuthUser = {
      id: payload.sub,
      email: payload.email,
      displayName: payload.displayName ?? payload.email,
      isAdmin: Boolean(row.is_admin)
    };

    req.authUser = user;
    next();
  } catch {
    res.status(401).json({
      error: "INVALID_TOKEN",
      message: "Access token is invalid or expired."
    });
  }
}
