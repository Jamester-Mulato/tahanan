import crypto from "node:crypto";
import { query } from "../config/db";

const TTL_DAYS = 7;

function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

/**
 * Issues a device token that lets this device skip the CAPTCHA for 7 days.
 * Only the hash is stored server-side.
 */
export async function createRememberToken(userId: string) {
  const token = crypto.randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + TTL_DAYS * 24 * 60 * 60 * 1000);

  await query("DELETE FROM login_remember_tokens WHERE expires_at <= now()");
  await query(
    `INSERT INTO login_remember_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [userId, hashToken(token), expiresAt]
  );

  return {
    rememberToken: token,
    rememberUntil: expiresAt.toISOString()
  };
}

export async function verifyRememberToken(
  email: string,
  token: string
): Promise<boolean> {
  const result = await query(
    `SELECT 1
       FROM login_remember_tokens r
       JOIN users u ON u.id = r.user_id
      WHERE lower(u.email) = lower($1)
        AND r.token_hash = $2
        AND r.expires_at > now()`,
    [email, hashToken(token)]
  );

  return (result.rowCount ?? 0) > 0;
}

export async function revokeRememberToken(token: string): Promise<void> {
  await query(
    `UPDATE login_remember_tokens
        SET expires_at = now()
      WHERE token_hash = $1`,
    [hashToken(token)]
  );
}

export async function revokeAllRememberTokens(userId: string): Promise<void> {
  await query(
    `UPDATE login_remember_tokens
        SET expires_at = now()
      WHERE user_id = $1`,
    [userId]
  );
}
