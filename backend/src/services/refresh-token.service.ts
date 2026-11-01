import crypto from "node:crypto";
import type { Request } from "express";
import { env } from "../config/env";
import { query } from "../config/db";

function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function describeDevice(req?: Request): string | null {
  const agent = req?.get("user-agent");
  if (!agent) return null;
  if (/android/i.test(agent)) return "Android";
  if (/iphone|ipad/i.test(agent)) return "iOS";
  if (/windows/i.test(agent)) return "Windows";
  if (/macintosh|mac os/i.test(agent)) return "macOS";
  if (/linux/i.test(agent)) return "Linux";
  return agent.slice(0, 80);
}

export interface RefreshTokenPair {
  refreshToken: string;
  refreshExpiresAt: string;
}

export async function createRefreshToken(
  userId: string,
  req?: Request
): Promise<RefreshTokenPair> {
  const token = crypto.randomBytes(48).toString("base64url");
  const expiresAt = new Date(
    Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000
  );

  await query(
    `INSERT INTO auth_refresh_tokens
       (user_id, token_hash, device_name, ip_address, user_agent, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [
      userId,
      hashToken(token),
      describeDevice(req),
      req?.ip ?? null,
      req?.get("user-agent") ?? null,
      expiresAt
    ]
  );

  return {
    refreshToken: token,
    refreshExpiresAt: expiresAt.toISOString()
  };
}

/**
 * Rotates a refresh token: the old one is revoked and a new one is issued.
 * Returns null when the token is unknown, revoked, or expired.
 */
export async function rotateRefreshToken(
  token: string,
  req?: Request
): Promise<{ userId: string } & RefreshTokenPair | null> {
  const existing = await query<{ id: string; user_id: string }>(
    `SELECT id, user_id
       FROM auth_refresh_tokens
      WHERE token_hash = $1
        AND revoked_at IS NULL
        AND expires_at > now()`,
    [hashToken(token)]
  );

  const row = existing.rows[0];
  if (!row) return null;

  await query(
    "UPDATE auth_refresh_tokens SET revoked_at = now() WHERE id = $1",
    [row.id]
  );

  const next = await createRefreshToken(row.user_id, req);
  return { userId: row.user_id, ...next };
}

export async function revokeRefreshToken(token: string): Promise<void> {
  await query(
    `UPDATE auth_refresh_tokens
        SET revoked_at = now()
      WHERE token_hash = $1
        AND revoked_at IS NULL`,
    [hashToken(token)]
  );
}

export async function revokeAllRefreshTokens(userId: string): Promise<void> {
  await query(
    `UPDATE auth_refresh_tokens
        SET revoked_at = now()
      WHERE user_id = $1
        AND revoked_at IS NULL`,
    [userId]
  );
}

export async function listRefreshSessions(userId: string) {
  const result = await query(
    `SELECT id,
            device_name AS "deviceName",
            ip_address AS "ipAddress",
            created_at AS "createdAt",
            last_used_at AS "lastUsedAt",
            expires_at AS "expiresAt"
       FROM auth_refresh_tokens
      WHERE user_id = $1
        AND revoked_at IS NULL
        AND expires_at > now()
      ORDER BY created_at DESC`,
    [userId]
  );

  return result.rows;
}

export async function revokeRefreshSession(
  userId: string,
  sessionId: string
): Promise<boolean> {
  const result = await query(
    `UPDATE auth_refresh_tokens
        SET revoked_at = now()
      WHERE id = $1
        AND user_id = $2
        AND revoked_at IS NULL`,
    [sessionId, userId]
  );

  return (result.rowCount ?? 0) > 0;
}
