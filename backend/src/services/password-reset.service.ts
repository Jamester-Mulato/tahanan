import crypto from "node:crypto";
import { env } from "../config/env";
import { query } from "../config/db";

const RESET_TTL_MINUTES = 10;

function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

/**
 * Creates a single-use 6-digit reset code. Only the hash is stored, so the
 * code exists in the clear only in the email that is sent to the user.
 */
export async function createPasswordResetToken(
  userId: string
): Promise<{ token: string; expiresAt: string }> {
  const token = String(crypto.randomInt(100000, 1000000));
  const expiresAt = new Date(Date.now() + RESET_TTL_MINUTES * 60 * 1000);

  await query(
    `UPDATE password_reset_tokens
        SET used_at = now()
      WHERE user_id = $1
        AND used_at IS NULL`,
    [userId]
  );

  await query(
    `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, $3)`,
    [userId, hashToken(token), expiresAt]
  );

  return { token, expiresAt: expiresAt.toISOString() };
}

/** Marks the code used and returns the user it belongs to, or null. */
export async function consumePasswordResetToken(
  token: string
): Promise<string | null> {
  const result = await query<{ id: string; user_id: string }>(
    `UPDATE password_reset_tokens
        SET used_at = now()
      WHERE token_hash = $1
        AND used_at IS NULL
        AND expires_at > now()
      RETURNING id, user_id`,
    [hashToken(token.trim())]
  );

  return result.rows[0]?.user_id ?? null;
}

export async function revokePasswordResetTokens(userId: string): Promise<void> {
  await query(
    `UPDATE password_reset_tokens
        SET used_at = now()
      WHERE user_id = $1
        AND used_at IS NULL`,
    [userId]
  );
}

export function passwordResetTtlMinutes(): number {
  return RESET_TTL_MINUTES;
}

export function logDevelopmentResetToken(email: string, token: string) {
  if (env.NODE_ENV !== "production") {
    console.log(`[dev-password-reset] ${email} ${token}`);
  }
}
